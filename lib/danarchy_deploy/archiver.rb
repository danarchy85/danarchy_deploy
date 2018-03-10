
module DanarchyDeploy
  class Archiver
    def self.new(archives, options)
      puts "\n" + self.name

      archives.each do |archive|
        abort("No target destination set for archive: #{archive[:source]}!") if !archive[:target]

        tmparchive = false
        if !archive[:source]
          archive[:source] = options[:deploy_dir] + "/.tmp_archive_#{DateTime.now.strftime("%Y%m%d_%H%M%S")}"
          tmparchive = true
        end

        if archive[:data]
          data = DanarchyDeploy::Helpers.decode_base64(archive[:data])
          write_tmp_archive(archive[:source], data)
        end
        
        puts " > Extracting #{archive[:source]} to #{archive[:target]}"

        if !File.exist?(archive[:source])
          puts "    ! Source file not found!: #{archive[:source]}"
          return false
        end

        Dir.exist?(archive[:target]) || FileUtils.mkdir_p(archive[:target])
        command = prep_extraction(archive, options)
        archive_result = DanarchyDeploy::Helpers.run_command(command, options)

        if archive_result[:stderr]
          puts '   ! Archive extraction failed!'
          abort("STDERR:\n#{archive_result[:stderr]}")
        else
          puts "   |+ Archive extracted: #{archive[:source]}\n"
        end

        cleanup_source_archive(archive[:source]) if tmparchive
      end
    end

    private
    def self.prep_extraction(archive, options)
      file_type = `file #{archive[:source]}`
      command = 'tar xvf '  if file_type.include?('POSIX tar archive')
      command = 'tar xvfj ' if file_type.include?('bzip2 compressed data')
      command = 'tar xvfz ' if file_type.include?('gzip compressed data')
      command = 'unzip '    if file_type.include?('Zip archive data')

      if options[:pretend]
        command  = command.gsub(/x/, 't') if command.start_with?('tar')
        command += '-t ' if command.start_with?('unzip')
      end

      command += archive[:source]
      command += " -C #{archive[:target]}" if command.start_with?('tar')
      command += " -d #{archive[:target]}" if command.start_with?('unzip')
      command
    end

    def self.write_tmp_archive(source, data)
      File.write(source, data)
    end

    def self.cleanup_source_archive(source)
      File.delete(source)
    end
  end
end
