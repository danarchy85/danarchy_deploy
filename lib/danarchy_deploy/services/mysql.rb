require_relative 'mysql/new_server'
require_relative 'mysql/privileges'

module DanarchyDeploy
  module Services
    class MySQL
      def self.new(os, mysql, options)
        puts "\n" + self.name
        puts "\n > Configuring MySQL service."

        mysql = self.set_parameters(mysql)
        self.generate_my_cnf(mysql, options)

        if File.exist?(mysql[:defaults_file]) && Dir.exist?(mysql[:datadir])
          puts "   |+ Using existing MySQL service."
        else
          MySQL::NewServer.new(os, mysql, options)
        end

        if mysql[:privileges]
          puts "\n > Configuring MySQL Privileges"
          MySQL::Privileges.new(mysql, options)
        end
      end

      def self.set_parameters(mysql)
        mysql[:defaults_file] = mysql[:defaults_file] ?
                                 mysql[:defaults_file] :
                                 '/root/.my.cnf'
        mysql[:my_cnf] = mysql[:my_cnf] ?
                           mysql[:my_cnf] :
                           '/etc/mysql/my.cnf'
        mysql[:datadir] = mysql[:datadir] ?
                            mysql[:datadir] :
                            '/var/lib/mysql'
        mysql[:bind_address] = mysql[:bind_address] ?
                                 mysql[:bind_address] :
                                 '127.0.0.1'

        mysql
      end

      def self.generate_my_cnf(mysql, options)
        source = options[:deploy_dir] +
                 '/templates/services/mysql/my.cnf.erb'
        
        templates = [{ target: mysql[:my_cnf],
                       source: source,
                       variables: {
                         datadir:      mysql[:datadir],
                         bind_address: mysql[:bind_address] }
                     }]

        DanarchyDeploy::Templater.new(templates, options)
      end
    end
  end
end
