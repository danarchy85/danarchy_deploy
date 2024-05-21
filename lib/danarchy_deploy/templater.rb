require 'erb'
require 'fileutils'

module DanarchyDeploy
  class Templater
    def self.load_source(source)
      if source =~ /^builtin::/
        source = File.expand_path('../../',  __dir__) + '/templates/' + source.split('::').last
      end

      abort("Source file does not exist at: #{source}") if ! File.exist?(source)
      source
    end

    def self.new(templates, options)
      puts "\n" + self.name

      if templates.map(&:keys).flatten.include?(:remove)
        puts ' > Removing templates tagged for removal.'
        templates = remove_templates(templates, options)
      end

      templates.each do |template|
        next if template[:remove]
        source = if !template[:target]
                   abort("No target destination set for template: #{template[:source]}!")
                 elsif template[:source].nil? && template[:data].nil?
                   abort("No source or data for template: #{template[:target]}")
                 elsif template[:data]
                   '-- encoded data --'
                 else
                   load_source(template[:source])
                 end

        target = template[:target]
        dir_perms = template[:dir_perms]
        file_perms = template[:file_perms]
        @variables = template[:variables] || nil
        puts "\n >  Checking: #{target}"
        puts "    Source:   #{source}"
        puts "    |> Dir  Permissions: #{dir_perms || '--undefined--'}"
        puts "    |> File Permissions: #{file_perms || '--undefined--'}"
        if options[:vars_verbose] && @variables
          puts '    |> Variables: '
          var = DanarchyDeploy::Helpers.hash_except(@variables, '^pass')
          puts var
        end

        tmpdir = options[:deploy_dir] + '/' + File.basename(File.dirname(target))
        Dir.exist?(tmpdir) || FileUtils.mkdir_p(tmpdir, mode: 0755)
        tmpfile = tmpdir + '/' + File.basename(target) + '.tmp'

        if source == '-- encoded data --'
          data = DanarchyDeploy::Helpers.decode_base64(template[:data])
          source = tmpfile + '.erb'
          write_tmpfile(source, data)
        end

        File.open(tmpfile, 'w') do |f|
          result = if RUBY_VERSION >= '2.6'
                     ERB.new(File.read(source), trim_mode: '-').result(binding)
                   else
                     ERB.new(File.read(source), nil, '-').result(binding)
                   end
          f.write(result)
          f.close
        end

        result = { write_erb: [], verify_permissions: {} }
        if options[:pretend]
          diff(target, tmpfile) if options[:vars_verbose]
          puts "\n    - Fake Run: Not changing '#{target}'."
          result[:verify_permissions][File.dirname(tmpfile)] = verify_permissions(File.dirname(tmpfile), dir_perms, options)
          result[:verify_permissions][tmpfile] = verify_permissions(tmpfile, file_perms, options)
        elsif files_identical?(target,tmpfile)
          puts "\n    - No change in '#{target}': Nothing to update here."
          result[:verify_permissions][File.dirname(target)] = verify_permissions(File.dirname(target), dir_perms, options)
          result[:verify_permissions][target] = verify_permissions(target, file_perms, options)
        else
          diff(target, tmpfile) if options[:vars_verbose]
          result[:write_erb] = enable_erb(target, tmpfile)
          puts "       |+ #{target} was updated!"
          result[:verify_permissions][File.dirname(target)] = verify_permissions(File.dirname(target), dir_perms, options)
          result[:verify_permissions][target] = verify_permissions(target, file_perms, options)
        end

        FileUtils.rm_rf(File.dirname(tmpfile))
        result
      end
    end

    private
    def self.verify_permissions(target, perms, options)
      (owner, group, mode) = nil
      chmod = nil
      puts "\n >  Verifying ownership and permissions for '#{target}'"
      if perms
        (owner, group, mode) = perms[:owner], perms[:group], perms[:mode]
      else
        if File.stat(target).mode & 07777 == '0777'.to_i(8)
          puts "     ! '#{target}' has 0777 permissions! Setting those to something more sane."
          if File.ftype(target) == 'directory'
            puts "    |+ Setting directory mode to: 0775"
            chmod = File.chmod(0775, target) ? true : false if !options[:pretend]
          elsif  File.ftype(target) == 'file'
            puts "    |+ Setting file mode to: 0644"
            chmod = File.chmod(0644, target) ? true : false if !options[:pretend]
          end
        else
          puts "    - Permissions were not defined for '#{target}'! Leaving them alone."
        end

        return [chmod]
      end

      (owner, uid, group, gid) = check_user_group(owner, group)

      updated = []
      file_stat = File.stat(target)
      if file_stat.uid != uid || file_stat.gid != gid
        puts "    |+ Setting ownership to: #{owner}:#{group}"
        chown = File.chown(uid, gid, target) ? true : false if !options[:pretend]
        updated.push(chown)
      end

      if file_stat.mode & 07777 != mode.to_i(8)
        puts "    |+ Setting file mode to: #{mode}"
        chmod = File.chmod(mode.to_i(8), target) ? true : false if !options[:pretend]
        updated.push(chmod)
      end

      updated
    end

    def self.check_user_group(owner, group)
      (uid, gid) = nil

      IO.popen("id -u #{owner} 2>/dev/null") do |id|
        uid = id.gets
        if uid == nil
          puts "     ! User:  #{owner} not found! Using: 'root'"
          owner = 'root'
          uid = 0
        end
        uid = uid.chomp.to_i if uid.class == String
      end

      IO.popen("id -g #{group} 2>/dev/null") do |id|
        gid = id.gets
        if gid == nil
          puts "     ! Group: #{group} not found! Using: 'root'"
          group = 'root'
          gid = 0
        end
        gid = gid.chomp.to_i if gid.class == String
      end

      [owner, uid, group, gid]
    end

    def self.files_identical?(target, tmpfile)
      if File.exist?(target) && File.exist?(tmpfile)
        FileUtils.identical?(target, tmpfile)
      elsif File.exist?(target) && !File.exist?(tmpfile)
        return false
      end
    end

    def self.diff(target, tmpfile)
      if File.exist?(target) && File.exist?(tmpfile)
        puts "\n!! Diff between #{target} <=> #{tmpfile}"
        IO.popen("diff -Naur #{target} #{tmpfile}") do |o|
          puts o.read
        end
        puts "\n!! End Diff \n\n"
      elsif File.exist?(target) && !File.exist?(tmpfile)
        return false
      end
    end

    def self.enable_erb(target, tmpfile)
      puts "\n    |+ Moving #{tmpfile} => #{target}"
      targetdir = File.dirname(target)
      Dir.exist?(targetdir) || FileUtils.mkdir_p(targetdir, mode: 0755)
      system("mv #{tmpfile} #{target}")
    end

    def self.write_tmpfile(source, data)
      File.write(source, data)
    end

    def self.remove_templates(templates, options)
      templates.delete_if do |template|
        if template.keys.include?(:remove)
          if options[:pretend]
            puts "    - Fake Run - Would have removed: '#{template[:target]}'."
            false
          elsif File.exist?(template[:target])
            puts "    |- Removing: #{template[:target]}"
            File.delete(template[:target])

            dirname = File.dirname(template[:target])
            if Dir.exist?(dirname) && Dir.empty?(dirname)
              puts "    |- Removing empty directory: #{dirname}"
              Dir.rmdir(dirname)
              if Dir.exist?(dirname)
                puts "      ! Failed to remove directory!"
              else
                puts "      - Removed directory."
              end
            end

            true
          end
        end
      end

      templates
    end
  end
end
