
module DanarchyDeploy
  module Applicator
    class PHPFPM
      def self.new(app, options)
        puts "\n" + self.name
        puts "\n > Checking #{app[:username]}'s PHP-FPM config."

        app = generate_paths(app, options)
        if app[:phpfpm] == 'enabled'
          enable_phpfpm(app, options)
        elsif app[:phpfpm] == 'disabled'
          disable_phpfpm(app, options)
        end

        app
      end

      def self.generate_paths(app, options)
        phpfpm_config = Dir['/etc/**/php-fpm.conf'].last
        sites_enabled = nil

        if phpfpm_config.nil? && options[:pretend]
          sites_enabled = '/etc/php/fpm-pretend/sites_enabled/'
          puts "   - Fake run: Testing deployment using #{sites_enabled}"
        elsif phpfpm_config.nil? && !options[:pretend]
          abort("\n  ! ERROR: Could not establish php-fpm.conf location!")
        else
          puts "   |+ Found php-fpm.conf at: #{phpfpm_config}."
          phpfpm_config = File.readlines(phpfpm_config)
          sites_enabled = phpfpm_config.grep(/^include/).last.gsub(/(^.*=|\*$|\*.conf)/, '').chomp        
        end

        app[:phpcfg] = app[:phpcfg] ?
                         app[:phpcfg] :
                         "/home/#{app[:username]}/php-fpm/sites-enabled/#{app[:domain]}.conf"
        # app[:phpcfg] = sites_enabled + "#{app[:domain].gsub('.','_')}.conf"
        app
      end

      def self.enable_phpfpm(app, options)
        tmpdir = "/home/#{app[:username]}/tmp"

        if !options[:pretend]
          puts "\n  |+ Enabling PHP-FPM for '#{app[:username]}'."
          FileUtils.mkdir_p(File.dirname(app[:phpcfg]))
          FileUtils.mkdir_p(tmpdir, mode: 1750)
          FileUtils.chown(app[:username], app[:username], tmpdir)
        end

        pool = app[:domain].gsub('.','_')
        web_user = 'nginx'  if app[:nginx]
        web_user = 'apache' if app[:apache]
        source = options[:deploy_dir] + '/templates/applications/php/phpfpm.conf.erb'
        templates = [{ target: app[:phpcfg],
                       source: source,
                       variables: { pool: pool,
                                    username: app[:username],
                                    web_user: web_user,
                                    tmp:      tmpdir },
                       dir_perms: { owner: 'root',
                                    group: 'root',
                                    mode: '0755' },
                       file_perms: { owner: 'root',
                                     group: 'root',
                                     mode: '0644' } }]

        DanarchyDeploy::Templater.new(templates, options)
      end

      def self.disable_phpfpm(app, options)
        if options[:pretend]
          puts "   - Fake run: Remove #{app[:user_phpcfg]}"
        else
          puts "\n  ! Disabling PHP-FPM for '#{app[:username]}'."
          if File.exist?(app[:phpcfg])
            File.delete(app[:phpcfg]) 
            puts "    |_ Removed: #{app[:phpcfg]}"
          end
        end
      end
    end
  end
end
