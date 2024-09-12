
module DanarchyDeploy
  module System
    class CentOS
      def self.new(deployment, options)
        puts "\n" + self.name
        puts "#{deployment[:os].capitalize} detected! Using yum."
        # needs more testing

        set_hostname(deployment[:hostname]) if !options[:pretend]
        installer = 'yum install -y '
        updater = 'yum upgrade -y'
        cleaner = 'yum clean all'

        [installer, updater, cleaner]
      end

      private
      def self.set_hostname(hostname)
        `hostnamectl set-hostname #{hostname}`
      end
    end
  end
end
