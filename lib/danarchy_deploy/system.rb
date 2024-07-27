require_relative 'system/centos'
require_relative 'system/debian'
require_relative 'system/gentoo'
require_relative 'system/opensuse'

require_relative 'system/cryptsetup'
require_relative 'system/fstab'

module DanarchyDeploy
  module System
    def self.new(deployment, options)
      abort('Operating System not defined! Exiting!') if !deployment[:os]
      puts "\n" + self.name

      installer, updater, cleaner = prep_operating_system(deployment, options)
      install_result, updater_result = nil, nil

      puts "\n > Package Installation"
      if [true, 'all', 'selected', nil].include?(deployment[:system][:update]) &&
         deployment[:packages].any?
        packages = deployment[:packages].join(' ')
        puts "\n   - Installing packages..."
        install_result = DanarchyDeploy::Helpers.run_command("#{installer} #{packages}", options)
        puts install_result[:stdout] if install_result[:stdout]
      else
        puts "\n   - Not installing packages."
        puts "       |_ Packages selected: #{deployment[:packages].count}"
        puts "       |_ Updates  selected: #{deployment[:system][:update]}"
      end

      puts "\n > #{deployment[:os].capitalize} System Updates"
      if [true, 'all', 'system', nil].include?(deployment[:system][:update])
        puts "\n   - Running system updates..."
        updater_result = DanarchyDeploy::Helpers.run_command(updater, options)
        puts updater_result[:stdout] if updater_result[:stdout]
      else
        puts "\n   - Not running #{deployment[:os].capitalize} system updates."
        puts "       |_ Updates selected: #{deployment[:system][:update]}"
      end

      if install_result || updater_result
        puts "\n   - Cleaning up unused packages..."
        cleanup_result = DanarchyDeploy::Helpers.run_command(cleaner, options)
        puts cleanup_result[:stdout] if cleanup_result[:stdout]
      end

      deployment
    end

    private
    def self.prep_operating_system(deployment, options)
      (installer, updater, cleaner) = nil
      os = deployment[:os]

      if deployment[:system]
        if deployment[:system][:archives]
          puts " > Deploying system archives"
          DanarchyDeploy::Archiver.new(deployment[:system][:archives], options)
        end

        if deployment[:system][:templates]
          puts "\n > Configuring system templates for #{deployment[:os]}"
          DanarchyDeploy::Templater.new(deployment[:system][:templates], options)
        end

        DanarchyDeploy::System::Cryptsetup.new(deployment[:os], deployment[:system][:cryptsetup], options)

        if deployment[:system][:fstab]
          DanarchyDeploy::System::Fstab.new(deployment[:os], deployment[:system][:fstab], options)
        else
          DanarchyDeploy::System::Fstab.mount_all(options)
        end
      end

      if os.downcase == 'gentoo'
        (installer, updater, cleaner) = DanarchyDeploy::System::Gentoo.new(deployment, options)
      elsif %w[debian ubuntu].include?(os.downcase)
        (installer, updater, cleaner) = DanarchyDeploy::System::Debian.new(deployment, options)
      elsif os.downcase == 'opensuse'
        puts 'OpenSUSE is not fully supported yet!'
        (installer, updater, cleaner) = DanarchyDeploy::System::OpenSUSE.new(deployment, options)
      elsif %w[fedora centos redhat].include?(os.downcase)
        puts 'Fedora/CentOS/RedHat is not fully supported yet!'
        (installer, updater, cleaner) = DanarchyDeploy::System::CentOS.new(deployment, options)
      end

      [installer, updater, cleaner]
    end

    def self.fstab_mount(deployment, options)
      fstab = deployment[:system][:templates].collect { |t| t if t[:target] == '/etc/fstab' }.compact
      fstab.each do |t|
        t[:variables].each do |v|
          if !Dir.exist?(v[:mountpoint])
            puts "Creating mountpoint: #{v[:mountpoint]}"
            FileUtils.mkdir_p(v[:mountpoint]) if !options[:pretend]
          end
        end
      end

      puts "\n > Mounting Filesystems"
      if !options[:pretend]
        mount_result = DanarchyDeploy::Helpers.run_command('mount -a', options)
        abort('   |! Failed to mount filesystems!') if mount_result[:stderr]
      end
    end
  end
end
