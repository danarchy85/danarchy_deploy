require_relative 'system/centos'
require_relative 'system/debian'
require_relative 'system/gentoo'
require_relative 'system/opensuse'

require_relative 'system/cryptsetup'

module DanarchyDeploy
  module System
    def self.new(deployment, options)
      abort('Operating System not defined! Exiting!') if !deployment[:os]
      puts "\n" + self.name

      installer, updater, cleaner = prep_operating_system(deployment, options)
      install_result = nil
      if deployment[:packages] && !deployment[:packages].empty?
        packages = deployment[:packages].join(' ')
        puts "\nInstalling packages..."
        install_result = DanarchyDeploy::Helpers.run_command("#{installer} #{packages}", options)
        puts install_result[:stdout] if install_result[:stdout]
      else
        puts "\nNo packages to install."
      end

      if !options[:pretend] && # Run updates/clean if last_deploy > 1hr ago
         (deployment[:last_deploy] && Time.now - Time.parse(deployment[:last_deploy]) > 3600)
        puts "\nRunning system updates..."
        updater_result = DanarchyDeploy::Helpers.run_command(updater, options)
        puts updater_result[:stdout] if updater_result[:stdout]
        puts "\nCleaning up unused packages..."
        cleanup_result = DanarchyDeploy::Helpers.run_command(cleaner, options)
        puts cleanup_result[:stdout] if cleanup_result[:stdout]
      end

      DanarchyDeploy::System::Cryptsetup.new(deployment[:os], deployment[:system][:cryptsetup], options)
      # fstab_mount(deployment, options)
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
      end

      if os.downcase == 'gentoo'
        (installer, updater, cleaner) = DanarchyDeploy::System::Gentoo.new(deployment, options)
      elsif %w[debian ubuntu].include?(os.downcase)
        (installer, updater, cleaner) = DanarchyDeploy::System::Debian.new(deployment, options)
      elsif os.downcase == 'opensuse'
        puts 'OpenSUSE is not fully supported yet!'
        (installer, updater, cleaner) = DanarchyDeploy::System::OpenSUSE.new(deployment, options)
      elsif %w[centos redhat].include?(os.downcase)
        puts 'CentOS/RedHat is not fully supported yet!'
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
