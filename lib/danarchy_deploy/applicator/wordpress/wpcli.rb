module DanarchyDeploy
  module Applicator
    module WordPress
      class WPCLI
        def initialize(app, options)
          puts "\n > Initializing WordPress CLI"
          @database = app[:database]
          @prefix   = app[:prefix]
          @path     = app[:path]
          @user     = app[:user]
          @options  = options
          wpcli_install
        end

        def install
          cmd = @prefix + "'wp core download --path=#{@path}'"
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        def update
          cmd = @prefix + "'wp core update --path=#{@path}'"
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        def version
          cmd = @prefix + "'wp core version --path=#{@path}'"
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        def check_update
          cmd = @prefix + "'wp core check-update --path=#{@path}'"
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        def siteurl
          cmd = @prefix + "'wp option get siteurl --path=#{@path}'"
          siteurl = DanarchyDeploy::Helpers.run_command(cmd, @options)

          if siteurl[:stdout]
            return siteurl[:stdout].chomp
          else
            return siteurl[:stderr]
          end
        end

        def import
          cmd = @prefix + "'wp db import #{@database[:backup]} --path=#{@path}'"
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        private

        def wpcli_install
          install_cmd = 'bash ' + __dir__ + '/wpcli_install.sh'
          wpcli_result = DanarchyDeploy::Helpers.run_command(
            install_cmd, @options)

          if wpcli_result[:stderr]
            abort('   ! WP-CLI installation failed!')
          else
            puts '   |+ WP-CLI installed.'
          end
        end
      end
    end
  end
end
