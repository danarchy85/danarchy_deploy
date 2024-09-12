
module DanarchyDeploy
  module System
    class OpenSUSE
      def self.new(deployment, options)
        puts "\n" + self.name
        puts "#{deployment[:os].capitalize} detected! Using zypper."

        set_hostname(deployment[:hostname]) if !options[:pretend]
        puts "Updating zypper repositories..."
        DanarchyDeploy::Helpers.run_command('sudo zypper refresh', options)

        installer = 'zypper install '
        updater = 'zypper upgrade'
        cleaner = nil
        zypper_refresh_repos = DanarchyDeploy::Helpers.run_command('zypper refresh', options)
        # Needs package checking & testing

        [installer, updater, cleaner]
      end

      private
      def set_hostname(hostname)
        `hostnamectl set-hostname #{hostname}`
      end
    end
  end
end
