# require 'mysql2'
# Need to run with CLI rather than Ruby gem to reduce dependencies when this isn't used.

module DanarchyDeploy
  module Services
    class MySQL
      class Privileges
        def self.new(mysql, options)
          sql_grants = sql_template(mysql, options)
          run_sql_grants(mysql, sql_grants, options)
        end

        def self.sql_template(mysql, options)
          sql_grants = '/root/.user_grants.sql'
          source = options[:deploy_dir] +
                   '/templates/services/mysql/user_db_grants.sql.erb'
          templates = [{ target: sql_grants,
                         source: source,
                         variables: mysql[:privileges] }]

          DanarchyDeploy::Templater.new(templates, options)
          sql_grants
        end
        
        def self.run_sql_grants(mysql, sql_grants, options)
          # Using CLI commands for now;
          #   mysql2 requires mysql client be installed even if we won't be using it.
          # client = Mysql2::Client.new(:default_file => default_file)
          cmd = "mysql --defaults-file=#{mysql[:default_file]} -v < #{sql_grants}"
          DanarchyDeploy::Helpers.run_command(cmd, options)
        end
      end
    end
  end
end
