module DanarchyDeploy
  module Applicator
    module WordPress
      class WPConfig
        def self.new(app, options)
          puts "\n > Checking WordPress Configuration"
          app = verify_generate_wp_salts(app, options)
          wp_config(app, options)
          app
        end

        private

        def self.wp_config(app, options)
          target = app[:path] + '/wp-config.php'
          source = options[:deploy_dir] + '/templates/applications/wordpress/wp-config.php.erb'

          templates = [{ target: app[:path] + '/wp-config.php',
                         source: options[:deploy_dir] + '/templates/applications/wordpress/wp-config.php.erb',
                         variables: { db_host:       app[:database][:db_host],
                                      db_name:       app[:database][:db_name],
                                      db_user:       app[:database][:db_user],
                                      db_pass:       app[:database][:db_pass],
                                      table_prefix:  app[:database][:table_prefix],
                                      wp_keys_salts: app[:database][:salts],
                         file_perms: { owner:        app[:username],
                                       group:        app[:username],
                                       mode:         '0644' } }
                       }]

          DanarchyDeploy::Templater.new(templates, options)
        end

        def self.verify_generate_wp_salts(app, options)
          puts "\n   > Verifying WP authentication salts for #{app[:domain]}"
          if app[:database][:salts]
            puts '     |- Salts already exist! Using those.'
          else
            puts '     |+ Generating Auth Salts...'
            uri = URI('https://api.wordpress.org/secret-key/1.1/salt/')
            app[:database][:salts] = Net::HTTP.get(uri)
          end

          app
        end
      end
    end
  end
end
