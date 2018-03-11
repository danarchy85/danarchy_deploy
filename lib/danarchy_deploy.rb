require_relative 'danarchy_deploy/version'

module DanarchyDeploy
  require_relative './danarchy_deploy/archiver'
  require_relative './danarchy_deploy/groups'
  require_relative './danarchy_deploy/helpers'
  require_relative './danarchy_deploy/installer'
  require_relative './danarchy_deploy/users'
  require_relative './danarchy_deploy/services'
  require_relative './danarchy_deploy/templater'

  class LocalDeploy
    def self.new(deployment, options)
      puts "\n" + self.name
      puts "Pretend run! Not making any changes." if options[:pretend]
        
      puts 'Begining Deployment:'
      printf("%12s %0s\n", 'Hostname:', deployment[:hostname])
      printf("%12s %0s\n", 'OS:', deployment[:os])
      printf("%12s %0s\n", 'Packages:', deployment[:packages].join(', ')) if deployment[:packages]

      deployment = DanarchyDeploy::Installer.new(deployment, options)
      deployment = DanarchyDeploy::Services.new(deployment, options)  if deployment[:services]
      deployment = DanarchyDeploy::Groups.new(deployment, options)    if deployment[:groups]
      deployment = DanarchyDeploy::Users.new(deployment, options)     if deployment[:users]
      deployment = DanarchyDeploy::Services.init(deployment, options) if deployment[:services]

      deployment[:last_deploy] = DateTime.now.strftime("%Y/%m/%d %H:%M:%S")
      puts "\nFinished Local Deployment at #{deployment[:last_deploy]}!"
      File.write(options[:deploy_file],
                 JSON.pretty_generate(deployment) if options[:deploy_file].end_with?('.json')
      File.write(options[:deploy_file], deployment.to_yaml) if options[:deploy_file].end_with?('.yaml')
      deployment
    end
  end

  class RemoteDeploy
    def self.new(deployment, options)
      puts "\n" + self.name
      options[:working_dir] = options[:deploy_dir] + '/' + deployment[:hostname]
      connector = { hostname: deployment[:hostname],
                    ipv4:     deployment[:ipv4],
                    ssh_user: deployment[:ssh_user],
                    ssh_key:  deployment[:ssh_key] }

      install_gem(connector, options)
      push_deployment(connector, options)
      deploy_result = remote_LocalDeploy(connector, options)

      if deploy_result[:stderr]
        puts '   ! Deployment failed!'
        abort("STDERR:\n#{deploy_result[:stderr]}")
      else
        puts deploy_result[:stdout]
      end

      pull_deployment(connector, options)
      remote_Cleanup(connector, options)

      puts "\nRemote deployment complete!"
      deployment = JSON.parse(File.read(options[:deploy_file]), symbolize_names: true) if options[:deploy_file].end_with?('.json')
      deployment = YAML.load_file(options[:deploy_file]) if options[:deploy_file].end_with?('.yaml')
      deployment
    end

    private
    def self.install_gem(connector, options)
      puts "\n > Installing danarchy_deploy on #{connector[:hostname]}"
      install_result = DanarchyDeploy::Helpers.run_command("ssh -i #{connector[:ssh_key]} #{connector[:ssh_user]}@#{connector[:ipv4]} -o ConnectTimeout=30 'sudo gem install -f danarchy_deploy && test -d #{options[:working_dir]} || sudo mkdir -vp #{options[:working_dir]} && sudo chown -Rc #{connector[:ssh_user]}:#{connector[:ssh_user]} #{options[:working_dir]}'", options)

      if install_result[:stderr]
        puts '   ! Gem install failed!'
        abort("STDERR:\n#{install_result[:stderr]}")
      else
        puts "   |+ Gem installed!"
      end
    end

    # Add ssh-keygen function, then update 
    def self.push_deployment(connector, options)
      puts "\n > Pushing deployment: #{options[:deploy_file]}"
      push_result = DanarchyDeploy::Helpers.run_command("rsync --rsh 'ssh -i #{connector[:ssh_key]}' -Havzu --delete #{options[:working_dir]}/ #{connector[:ssh_user]}@#{connector[:ipv4]}:#{options[:working_dir]}/", options)
      # push_result = DanarchyDeploy::Helpers.run_command("scp -i #{connector[:ssh_key]} #{options[:deploy_file]} #{connector[:ssh_user]}@#{connector[:ipv4]}:#{options[:deploy_dir]}/#{connector[:hostname]}/", options)
      
      if push_result[:stderr]
        puts '   ! Deployment push failed!'
        abort("STDERR:\n#{push_result[:stderr]}")
      else
        puts "   |+ Deployment pushed!"
      end
    end

    def self.remote_LocalDeploy(connector, options)
      puts "\n > Running LocalDeploy on #{connector[:hostname]}\n\tOutput will return at the end of deployment."

      deployment =  "ssh -i #{connector[:ssh_key]} #{connector[:ssh_user]}@#{connector[:ipv4]} 'sudo danarchy_deploy local "
      deployment += '--first-run '   if options[:first_run]
      deployment += '--ssh-verbose ' if options[:ssh_verbose]
      deployment += '--pretend '     if options[:pretend]
      deployment += '--json '        if options[:deploy_file].end_with?('.json')
      deployment += '--yaml '        if options[:deploy_file].end_with?('.yaml')
      deployment += options[:deploy_file] + '\''

      DanarchyDeploy::Helpers.run_command(deployment, options)
    end

    def self.pull_deployment(connector, options)
      puts "\n > Pulling deployment: #{options[:deploy_file]}"
      pull_result = DanarchyDeploy::Helpers.run_command("scp -i #{connector[:ssh_key]} #{connector[:ssh_user]}@#{connector[:ipv4]}:#{options[:deploy_file]} #{options[:deploy_file]}", options)
      
      if pull_result[:stderr]
        puts '   ! Deployment pull failed!'
        abort("STDERR:\n#{pull_result[:stderr]}")
      else
        puts "   |+ Deployment pulled!"
      end
    end

    def self.remote_Cleanup(connector, options)
      puts "\n > Cleaning up: #{options[:deploy_dir]}"
      cleanup_result = DanarchyDeploy::Helpers.run_command("ssh -i #{connector[:ssh_key]} #{connector[:ssh_user]}@#{connector[:ipv4]} 'sudo rm -rfv #{options[:working_dir]}'", options)

      if cleanup_result[:stderr]
        puts '   ! Deployment cleanup failed!'
        abort("STDERR:\n#{cleanup_result[:stderr]}")
      else
        puts "   |+ Deployment cleaned up!"
      end
    end
  end
end
