require 'net/http'

module DanarchyDeploy
  module System
    class Debian
      def self.new(deployment, options)
        puts "\n" + self.name
        puts "#{deployment[:os].capitalize} detected! Using apt."

        set_hostname(deployment[:hostname]) if !options[:pretend]
        if deployment[:apt]
          if deployment[:apt][:templates]
            puts "\nChecking Apt configs."
            DanarchyDeploy::Templater.new(deployment[:apt][:templates], options)
          end

          if deployment[:apt][:gpgkeys]
            puts "\nInstalling Apt GPG Keys."
            install_gpgkeys(deployment[:apt][:gpgkeys], options)
          end
        end

        nonint = 'export DEBIAN_FRONTEND=noninteractive ; '
        installer  = nonint + 'apt-get install -y '
        installer += '--dry-run ' if options[:pretend]
        updater = nonint + 'apt-get upgrade -y '
        cleaner = nonint + 'apt-get autoclean -y '

        puts "\nUpdating Apt repos..."
        DanarchyDeploy::Helpers.run_command(nonint + 'apt-get update', options)

        [installer, updater, cleaner]
      end

      private
      def self.install_gpgkeys(gpgkeys, options)
        gpgkeys.each do |url|
          puts "\n > Acquiring GPG key from: #{url}"
          tmpfile = '/var/tmp/' + `date +%s`.chomp + '.gpgkey.tmp'
          gpgkey = Net::HTTP.get(URI(url))
          if ! gpgkey
            abort('  ! GPG key download failed!')
          else
            puts "   |+ GPG key successfully downloaded!"
            File.write(tmpfile, gpgkey)
            abort("  ! Failed to write tmpfile for url: #{url} => #{tmpfile}") if ! File.exist?(tmpfile)

            # Silence noise about non-TTY terminal thanks to apt-key
            gpgcmd = "export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=false; apt-key add -qq #{tmpfile}"
            gpg_result = DanarchyDeploy::Helpers.run_command(gpgcmd, { quiet: true })

            if gpg_result[:stderr]
              abort("    ! Failed to write key for: #{url}")
            elsif gpg_result[:stdout]
              puts "   |+ GPG Key saved!"
            end
          end
        end
      end

      private
      def set_hostname(hostname)
        `hostnamectl set-hostname #{hostname}`
      end
    end
  end
end
