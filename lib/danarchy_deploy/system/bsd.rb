
module DanarchyDeploy
  module System
    class BSD
      def self.new(deployment, options)
        puts "\n" + self.name
        puts 'BSD detected! Using pkg.'

        set_hostname(deployment[:hostname]) if !options[:pretend]
        installer = 'pkg install -y '
        update    = 'pkg upgrade -y '
        cleaner   = 'pkg clean -y '

        puts "\n Updating Pkg repos..."
        DanarchyDeploy::Helpers.run_command('pkg update -q',options)
        [installer, updater, cleaner]
      end

      private
      def self.set_hostname(hostname)
        `hostname #{hostname}`
      end
    end
end
