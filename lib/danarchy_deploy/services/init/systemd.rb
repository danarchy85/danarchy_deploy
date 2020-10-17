
module DanarchyDeploy
  module Services
    class Init
      class Systemd
        def initialize(service, options)
          @service = service
          @options = options
        end

        def status
          cmd = "systemctl show #{@service} --no-page"
          # return { stdout: "Fake run: started", stderr: nil } if @options[:pretend]
          status = DanarchyDeploy::Helpers.run_command(cmd, @options)
          status[:stdout].split(/\n/).grep(/ActiveState/).first.split('=').last
        end

        def start
          cmd = "systemctl start #{@service}"
          status = self.status

          if status == 'active'
            return status
          else
            DanarchyDeploy::Helpers.run_command(cmd, @options)
          end
        end

        def stop
          cmd = "systemctl #{@service} stop"
          status = self.status

          if status == 'inactive'
            return status
          else
            DanarchyDeploy::Helpers.run_command(cmd, @options)
          end
        end

        def reload
          status = self.status

          cmd = if status == 'inactive'
                  "systemctl start #{@service}"
                else
                  "systemctl reload #{@service}"
                end

          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        def restart
          cmd = "systemctl restart #{@service}"
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        def enable
          cmd = "systemctl enable #{@service}"
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        def disable
          cmd = "systemctl enable #{@service}"
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end
      end
    end
  end
end
