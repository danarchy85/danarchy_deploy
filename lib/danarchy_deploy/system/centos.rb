
module DanarchyDeploy
  module System
    class CentOS
      def self.new(deployment, options)
        puts "\n" + self.name
        puts "#{deployment[:os].capitalize} detected! Using yum."
        # needs more testing
        installer = 'yum install -y '
        updater = 'yum upgrade -y'
        cleaner = 'yum clean all'

        [installer, updater, cleaner]
      end
    end
  end
end
