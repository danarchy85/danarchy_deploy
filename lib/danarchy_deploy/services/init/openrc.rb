
module DanarchyDeploy
  module Services
    class Init
      class Openrc
        def initialize(service, runlevel='default', options)
          @service  = service
          @runlevel = runlevel
          @options  = options
          cleanup_runlevels
        end

        def status
          cmd = "rc-service #{@service} status"
          return { stdout: "Fake run: started", stderr: nil } if @options[:pretend]
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        def start
          cmd = "rc-service #{@service} start"
          status = self.status

          if status[:stdout].include?('started')
            return status
          else
            DanarchyDeploy::Helpers.run_command(cmd, @options)
          end
        end

        def stop
          cmd = "rc-service #{@service} stop"
          status = self.status

          if status[:stdout].include?('stopped')
            return status
          else
            DanarchyDeploy::Helpers.run_command(cmd, @options)
          end
        end

        def reload
          status = self.status

          cmd = if status[:stderr]
                  # status[:stdout].include?('running')
                  # This used to check for status "running"; and previously "started".
                  # Too specific so I've disabled it since I don't remember what this exception was for, originally.
                  puts "        |! Service: #{@service} is not running. Starting it up instead."
                  "rc-service #{@service} start"
                else
                  "rc-service #{@service} reload"
                end

          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        def restart
          cmd = "rc-service #{@service} restart"
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        def enable
          cmd = "rc-update add #{@service} #{@runlevel}"
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        def disable
          cmd = "rc-update del #{@service} #{runlevel}"
          DanarchyDeploy::Helpers.run_command(cmd, @options)
        end

        private
        def cleanup_runlevels
          Dir["/etc/runlevels/*/#{@service}"].each do |dir|
            runlevel = File.basename(File.dirname(dir))
            if runlevel != @runlevel
              puts "    |> Removing #{@service} from wrong runlevel: #{runlevel}"
              cmd = "rc-update del #{@service} #{runlevel}"
              DanarchyDeploy::Helpers.run_command(cmd, @options)
            end
          end
        end
      end
    end
  end
end
