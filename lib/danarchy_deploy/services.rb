
module DanarchyDeploy
  class Services
    def self.new(deployment, options)
      puts "\n" + self.name

      deployment[:services].each do |service, params|
        puts "Configuring service: #{service}"

        if params[:templates] && !params[:templates].empty?
          puts " > COnfiguring templates for #{service}"
          DanarchyDeploy::Templater.new(params[:templates], options)
        end

        if params[:archives] && !params[:archives].empty?
          puts "\n" + self.name
          puts " > Deploying archives for #{service}"
          DanarchyDeploy::Archiver.new(params[:archives], options)
        end
      end

      deployment
    end

    private
    def self.init(deployment, options)
      puts "\n" + self.name

      deployment[:services].each do |service, params|
        next if !params[:init]
        if options[:first_run] == false
          puts "    ! Not a first-time run! Setting actions to 'reload'.\n\tUse --first-run to run actions: #{params[:init].join(' ,')}\n"
          params[:init] = ['reload']
        end

        params[:init].each do |action|
          puts " > Taking action: #{action} on #{service}"
          command = "systemctl #{action} #{service}"

          if options[:pretend]
            puts "    Fake run: #{command}\n"
          else
            DanarchyDeploy::Helpers.run_command(command, options)
          end
        end
      end

      deployment
    end
  end
end
