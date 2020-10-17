
module DanarchyDeploy
  module Services
    class MySQL
      class NewServer
        def self.new(os, mysql, options)
          self.generate_root_mycnf(mysql, options)

          if os == 'gentoo'
            self.gentoo_new_mysql(mysql, options)
          elsif os == 'opensuse'
            self.opensuse_new_mysql(mysql, options)
          elsif %w[debian ubuntu].include?(os)
            self.debian_new_mysql(mysql, options)
          elsif %w[centos redhat].include?(os)
            self.centos_new_mysql(mysql, options)
          end
        end

        private

        def self.gentoo_new_mysql(mysql, options)
          puts "\n > Performing first time MySQL configuration."
          cmd = 'emerge --config mariadb'
          config_result = DanarchyDeploy::Helpers.run_command(cmd, options)

          if config_result[:stderr]
            abort('   |! ERROR: Failed to configure MySQL')
          else config_result[:stdout]
            puts "   |+ MySQL configured successfully"
            puts config_result[:stdout]
          end

          puts "\n > Starting MySQL."
          DanarchyDeploy::Services::Init.init_manager('gentoo', 'mysql', 'start', options)
        end

        def self.debian_new_mysql(mysql, options)
          puts "   ! Debian/Ubuntu MySQL configuration not yet implemented!"
        end

        def self.centos_new_mysql(mysql, options)
          puts "   ! CentOS/Redhat MySQL configuration not yet implemented!"
          
        end

        def self.opensuse_new_mysql(mysql, options)
          puts "   ! OpenSUSE MySQL configuration not yet implemented!"
        end

        def self.generate_root_mycnf(mysql, options)
          return if File.exist?(mysql[:default_file])
          puts "   |+ Generating #{mysql[:default_file]} file."
          password = SecureRandom.base64(14)
          source = options[:deploy_dir] +
                   '/templates/services/mysql/root_my.cnf.erb'

          templates = [{ target: mysql[:default_file],
                         source: source,
                         variables: {
                           host: 'localhost',
                           user: 'root',
                           pass: password,
                           port: '3306' }
                       }]

          DanarchyDeploy::Templater.new(templates, options)
        end
      end
    end
  end
end
