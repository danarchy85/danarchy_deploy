
module DanarchyDeploy
  module Applicator
    class Nginx
      def self.new(app, options)
        puts "\n" + self.name
        puts "\n > Checking Nginx configuration for #{app[:username]}."

        app = generate_paths(app, options)
        if app[:nginx] == 'enabled'
          enable_nginx(app, options)
        elsif app[:nginx] == 'disabled'
          disable_nginx(app, options)
        end

        app
      end

      def self.generate_paths(app, options)
        nginx_config = Dir['/etc/nginx/**/nginx.conf'].last
        sites_enabled = nil

        if nginx_config.nil? && options[:pretend]
          sites_enabled = '/etc/nginx/sites_enabled/'
          puts "   - Fake run: Testing deployment using #{sites_enabled}"
        elsif nginx_config.nil? && !options[:pretend]
          abort("\n  ! ERROR: Could not establish nginx.conf location!")
        else
          nginx_config = File.readlines(nginx_config)
          sites_enabled = nginx_config.grep(/include/).last.gsub(/\s+include |\*.conf;/, '').chomp.gsub(/\*;/, '')
        end

        app[:domaincfg] = app[:domaincfg] ?
                              app[:domaincfg] :
                              "/home/#{app[:username]}/nginx/sites-enabled/#{app[:domain]}.conf"
        # app[:domaincfg] = "/home/#{app[:username]}/nginx/sites-enabled/#{app[:domain]}.conf" #sites_enabled + "#{app[:domain]}.conf"
        app[:log_dir] = app[:log_dir] ?
                          app[:log_dir] :
                          "/home/#{app[:username]}/nginx/logs/#{app[:domain]}"
        app
      end

      def self.enable_nginx(app, options)
        if !options[:pretend]
          puts "\n   |+ Enabling Nginx for '#{app[:domain]}'."
          FileUtils.mkdir_p([File.dirname(app[:domaincfg]), app[:log_dir]])
          FileUtils.chown_R(app[:username], app[:username], "/home/#{app[:username]}/nginx")
          DanarchyDeploy::Users.add_to_group({username: 'nginx', groups: [app[:username]]}, options)
        end

        source = options[:deploy_dir] + '/templates/applications/nginx/domain.conf.erb'
        template = { target: app[:domaincfg],
                     source: source,
                     variables: { username: app[:username],
                                  domain:   app[:domain] },
                     dir_perms: { owner: app[:username],
                                  group: app[:username],
                                  mode: '0755' },
                     file_perms: { owner: app[:username],
                                   group: app[:username],
                                   mode: '0644' } }

        # if app[:ssl]
        #   if app[:ssl][:type] == 'letsencrypt'
        #     DanarchyDeploy::Applicator::SSL::LetsEncrypt.new(template, options)
        #   end
        # end

        templates = [template]
        DanarchyDeploy::Templater.new(templates, options)
      end

      def self.disable_nginx(app, options)
        if options[:pretend]
          puts "   - Fake run: Remove #{app[:domaincfg]}"
        else
          puts "\n   ! Disabling Nginx for '#{app[:domain]}'."
          if File.exist?(app[:domaincfg])
            File.delete(app[:domaincfg])
            puts "    |_ Removed: #{app[:domaincfg]}"
          end
        end
      end
    end
  end
end
