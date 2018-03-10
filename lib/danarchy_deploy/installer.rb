
module DanarchyDeploy
  class Installer
    def self.new(deployment, options)
      # available opts: { pretend: true|false }
      abort('Operating System not defined! Exiting!') if !deployment[:os]
      puts "\n" + self.name

      os = deployment[:os]
      packages = deployment[:packages]
      installer, updater, cleaner, packages = prep_operating_system(os, packages, options)
      install_result = nil
      if packages
        install_result = DanarchyDeploy::Helpers.run_command("#{installer} #{packages}", options)
      else
        puts 'No packages to install.'
      end

      if !options[:pretend]
        puts "\nRunning system updates..."
        updater_result = DanarchyDeploy::Helpers.run_command(updater, options)
        puts updater_result[:stdout] if updater_result[:stdout]
        puts "\nCleaning up unused packages..."
        cleanup_result = DanarchyDeploy::Helpers.run_command(cleaner, options)
        puts cleanup_result[:stdout] if cleanup_result[:stdout]
      end

      # [install_result, cleanup_result, updater_result]
      deployment
    end

    private
    def self.prep_operating_system(os, packages, options)
      (installer, updater, cleaner) = nil
      if os.downcase == 'gentoo'
        puts "#{os.capitalize} detected! Using emerge."

        if packages
          installer  =  'emerge --usepkg --quiet --noreplace '
          installer += '--pretend ' if options[:pretend]

          packages.each do |pkg|
            IO.popen("qlist -I #{pkg}") do |o|
              packages.delete(pkg) if !o.read.empty?
            end
          end
        end

        cleaner  = 'emerge --depclean --quiet '
        cleaner += '--pretend ' if options[:pretend]

        updater  = 'emerge --update --deep --newuse --quiet --with-bdeps=y @world'
        updater += ' --pretend' if options[:pretend]
      elsif %w[debian ubuntu].include?(os.downcase)
        puts "#{os.capitalize} detected! Using apt."
        installer  = 'export DEBIAN_FRONTEND=noninteractive ; apt install -y -qq '
        installer += '--dry-run ' if options[:pretend]
        updater = 'apt-get upgrade -y -qq'
        cleaner = 'apt-get autoclean -y -qq'
      elsif os.downcase == 'opensuse'
        puts "#{os.capitalize} detected! Using zypper."
        installer = 'zypper install '
        updater = nil
        cleaner = nil
        # Needs package checking & testing
      elsif %w[centos redhat].include?(os.downcase)
        # needs more testing
        puts "#{os.capitalize} detected! Using yum."
        if packages
          installer = 'yum install -y '

          packages.each do |pkg|
            IO.popen("rpm -q #{pkg}") do |o|
              packages.delete(pkg) if !o.read.include?('not installed')
            end
          end
        end

        updater = nil
        cleaner = nil
      end

      [installer, updater, cleaner, packages.join(' ')]
    end
  end
end
