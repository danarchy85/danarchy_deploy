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
          orig_actions = params[:init]
          puts "\n > Init actions for #{service}: #{params[:init].join(', ')}"
          params[:init].each do |action|
            puts "    |+ Taking action: #{action} on #{service}"
            if options[:pretend]
              puts "       Fake run: #{action} #{service}"
            else
              init_manager(deployment[:os], service, action, options)
            end
          end

          params[:init] = orig_actions
        end

        deployment
      end

      def self.init_manager(os, service, action, options)
        init = if os == 'gentoo'
                 DanarchyDeploy::Services::Init::Openrc.new(service, options)
               else
                 DanarchyDeploy::Services::Init::Systemd.new(service, options)
               end

        init_result = init.send(action)

        if stderr = init_result[:stderr]
          if stderr.include?('unknown function')
            puts "       ! Action: #{action} not available for service: #{service}.\n" +
                 "          ! A restart may be needed! Otherwise, remove this action from the deployment.\n" +
                 "          ! Not taking any action here.\n"
          else
            abort("       ! Action: #{action} #{service} failed!")
          end
        else
          puts "       |+ Action: #{action} #{service} succeeded."
        end
      end
    end
  end
end
