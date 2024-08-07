require_relative 'init/openrc'
require_relative 'init/systemd'

module DanarchyDeploy
  module Services
    class Init
      def self.new(deployment, options)
        return deployment if ! deployment[:services]
        puts "\n" + self.name

        deployment[:services].each do |service, params|
          next if ! params[:init]
          if params[:init].class == Array
            # one-time update for :init to new format
            params[:init] =  if deployment[:os] == 'gentoo'
                               { runlevel: 'default', actions: params[:init] }
                             else
                               { actions: params[:init] }
                             end
          end

          init_manager(deployment[:os], service, params[:init][:runlevel], options)
          puts "\n > Init actions for #{service}: #{params[:init][:actions].join(', ')}"
          params[:init][:actions].each do |action|
            puts "    |> Taking action: #{action} on #{service}"
            if options[:pretend]
              puts "     |- Fake run: #{action} #{service}"
            else
              init_run(action)
            end
          end
        end

        deployment
      end

      private
      def self.init_manager(os, service, runlevel='default', options)
        @init = if os == 'gentoo'
                  DanarchyDeploy::Services::Init::Openrc.new(service, runlevel, options)
                else
                  DanarchyDeploy::Services::Init::Systemd.new(service, options)
                end
      end

      def self.init_run(action)
        init_result = @init.send(action)

        if stderr = init_result[:stderr]
          if stderr.include?('unknown function')
            puts "       ! Action: #{action} not available for service.\n" +
                 "          ! A restart may be needed! Otherwise, remove this action from the deployment.\n" +
                 "          ! Not taking any action here.\n"
          else
            abort("       ! Action: #{action} failed!")
          end
        else
          puts "       |+ Action: #{action} succeeded."
        end
      end
    end
  end
end
