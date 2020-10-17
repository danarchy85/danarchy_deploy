require 'net/http'
require_relative 'wordpress/wpcli'
require_relative 'wordpress/wpconfig'

module DanarchyDeploy
  module Applicator
    module WordPress
      def self.new(app, options)
        puts "\n" + self.name
        puts " > Checking on WordPress installation at '#{app[:path]}'."

        app[:prefix] = cmd_prefix(app)
        wpcli = WordPress::WPCLI.new(app, options)
        app   = WordPress::WPConfig.new(app, options)

        # if options[:first_run] && 
        wpcli.install if wpcli.version[:stderr] =~
                         /Error: This does not seem to be a WordPress install/

        siteurl = wpcli.siteurl
        if siteurl =~ /http.*:\/\/(www.|)#{app[:domain]}/
          puts "   |+ Siteurl: #{siteurl} found in the WP database. Continuing with deployment."
        elsif siteurl =~ /Error: The site you have requested is not installed/
          puts "   |! Domain: #{app[:domain]} not found in current database."

          db_backup = app[:path] + '/' + app[:domain].gsub('.','_') + '.sql'
          if File.exist?(db_backup) && options[:first_run]
            puts "   |+ Importing from local backup."
            import = wpcli.import
          else
            puts "   |- . No database content! Skipping deployment of #{app[:domain]}."
            return app
          end
        else
          puts "   ! Domain: #{app[:domain]} does not match the database's current siteurl: #{siteurl}"
          puts "     |- Skipping #{app[:domain]} deployment"
          return app
        end
          
        if app[:autoupdate]
          wpcli.update
        else
          wpcli.check_update
        end

        app.delete(:prefix)
        app        
      end
        # if options[:pretend]
          # puts "\tFake run: Skipping WordPress configuration for #{app[:domain]}"
        # else
          # verify_result = wp_ensure_installed(prefix, app, options)

          # if verify_result[:stderr]
          #   puts "   |+ Installing WordPress to: #{app[:path]}"
          #   install_result = wp_install(prefix, app, options)
          #   abort('   ! WordPress installation failed!') if install_result[:stderr]
          #   verify_result = wp_ensure_installed(prefix, app, options)
          #   abort('   ! WordPress verification failed!')  if verify_result[:stderr]
          # end

          # puts "   |+ WordPress #{verify_result[:stdout].chomp} found!" if verify_result[:stdout]
          # app = verify_generate_wp_salts(app, options)
          # DanarchyDeploy::Templater.new(app[:templates], options)
        # end
        
        # puts "\n > Verifying wp-config.php for '#{app[:path]}/wp-config.php'."
        # wp_config_new(app, options)
      #   app
      # end

      private
      def self.cmd_prefix(app)
        "sudo -u #{app[:username]} bash -c "
        # wp_root_mkdir(prefix, app, options)
        # wp_cli_install(options)
        # prefix
      end

      def self.wp_root_mkdir(prefix, app, options)
        mkdir_cmd = prefix + "'test -d #{app[:path]} || mkdir -v #{app[:path]}'"
        mkdir_result = DanarchyDeploy::Helpers.run_command(mkdir_cmd, options)

        if mkdir_result[:stderr]
          abort("   ! Failed to create directory: #{app[:path]}!")
        elsif mkdir_result[:stdout]
          puts "   |+ Created directory: #{app[:path]}"
        end
      end

      def self.wp_cli_install(options)
        wpcli_install = 'bash ' + File.expand_path(
                          File.dirname(__FILE__) +
                          '/wordpress/wpcli_install.sh')
        wpcli_result = DanarchyDeploy::Helpers.run_command(wpcli_install, options)

        if wpcli_result[:stderr]
          abort('   ! WP-CLI installation failed!')
        else
          puts '   |+ WP-CLI installed.'
        end
      end

      def self.wp_ensure_installed(prefix, app, options)
        installed = false
        version = nil
        
        if Dir.entries(app[:path]) == %w[. ..]
          puts "   |+ Installing WordPress to: #{app[:path]}"
          wp_install(prefix, app, options)
          # wp_config_new(app, options)
          # return 
        end

        version = wp_version(prefix, app, options)
        # Error: This does not seem to be a WordPress install.
      end

      def self.wp_install(prefix, app, options)
        cmd = prefix + "'wp core download --path=#{app[:path]}'"
        DanarchyDeploy::Helpers.run_command(cmd, options)
      end

      def self.wp_update(prefix, app, options)
        cmd = prefix + "'wp core update --path=#{app[:path]}'"
        DanarchyDeploy::Helpers.run_command(cmd, options)
      end

      def self.wp_version(prefix, app, options)
        cmd = prefix + "'wp core version --path=#{app[:path]}'"
        DanarchyDeploy::Helpers.run_command(cmd, options)
      end

      def self.wp_verify_uptodate()
        check_cmd = prefix + "'wp core check-update --path=#{app[:path]}'"
        DanarchyDeploy::Helpers.run_command(check_cmd, options)
      end

      def self.wp_config_verify(prefix, app, options)
        config_cmd = prefix + "wp config list DB_USER DB_PASSWORD DB_NAME DB_HOST table_prefix --path=#{app[:path]} --format=json"
        wp_config_current = JSON.parse(`#{config_cmd}`)
        p wp_config_current
      end
    end
  end
end
