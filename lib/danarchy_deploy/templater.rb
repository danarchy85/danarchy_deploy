require 'erb'
require 'fileutils'

module DanarchyDeploy
  class Templater
    def self.new(templates, options)
      puts "\n" + self.name

      templates.each do |template|
        abort("No target destination set for template: #{template[:source]}!") if !template[:target]
        abort("No source or data for template: #{template[:target]}") if !template[:source] && !template[:data]
        
        target = template[:target]
        source = template[:source] || '-- encoded data --'
        dir_perms = template[:dir_perms]
        file_perms = template[:file_perms]
        @variables = template[:variables] || nil
        puts "\n >  Checking: #{target}"
        puts "    Source:   #{source}"
        puts "    |> Dir  Permissions: #{dir_perms || '--undefined--'}"
        puts "    |> File Permissions: #{file_perms || '--undefined--'}"
        puts "    |> Variables: #{@variables}" if @variables

        targetdir = File.dirname(target)
        tmpdir = options[:deploy_dir] + '/' + File.basename(File.dirname(target))
        p tmpdir
        Dir.exist?(targetdir) || FileUtils.mkdir_p(targetdir, mode: 0755)
        Dir.exist?(tmpdir) || FileUtils.mkdir_p(tmpdir, mode: 0755)
        tmpfile = tmpdir + '/' + File.basename(target) + '.tmp'

        if source == '-- encoded data --'
          data = DanarchyDeploy::Helpers.decode_base64(template[:data])
          source = tmpfile + '.erb'
          write_tmpfile(source, data)
        end

        File.open(tmpfile, 'w') do |f|
          result = ERB.new(File.read(source)).result(binding)
          f.write(result)
          f.close
        end

        result = { write_erb: [], verify_permissions: {} }
        if options[:pretend]
          diff(target, tmpfile)
          puts "\n   - Fake Run: Not changing '#{target}'."
          result[:verify_permissions][File.dirname(tmpfile)] = verify_permissions(File.dirname(tmpfile), dir_perms, options)
          result[:verify_permissions][tmpfile] = verify_permissions(tmpfile, file_perms, options)
        elsif md5sum(target,tmpfile) == true
          puts "\n   - No change in '#{target}': Nothing to update here."
          result[:verify_permissions][File.dirname(target)] = verify_permissions(File.dirname(target), dir_perms, options)
          result[:verify_permissions][target] = verify_permissions(target, file_perms, options)
        else
          diff(target, tmpfile)
          result[:write_erb] = enable_erb(target, tmpfile)
          puts " => #{target} was updated!"
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
            puts "    |+ Setting file mode to: 0775"
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

    def self.md5sum(target, tmpfile)
      if File.exist?(target) && File.exist?(tmpfile)
        FileUtils.identical?(target, tmpfile)
      elsif File.exist?(target) && !File.exist?(tmpfile)
        return false
      end
    end

    def self.diff(target, tmpfile)
      if File.exist?(target) && File.exist?(tmpfile)
        puts "\n    !! Diff between #{target} <=> #{tmpfile}"
        IO.popen("diff -Naur #{target} #{tmpfile}") do |o|
          puts o.read
        end
        puts "\n    !! End Diff \n\n"
      elsif File.exist?(target) && !File.exist?(tmpfile)
        return false
      end
    end

    def self.enable_erb(target, tmpfile)
      puts "\n    |+ Moving #{tmpfile} => #{target}"
      system("mv #{tmpfile} #{target}")
    end

    def self.write_tmpfile(source, data)
      File.write(source, data)
    end
  end
end
