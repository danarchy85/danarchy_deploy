module DanarchyDeploy
  require_relative 'danarchy_deploy/applicator'
  require_relative 'danarchy_deploy/archiver'
  require_relative 'danarchy_deploy/groups'
  require_relative 'danarchy_deploy/hash_deep_merge'
  require_relative 'danarchy_deploy/helpers'
  require_relative 'danarchy_deploy/services'
  require_relative 'danarchy_deploy/system'
  require_relative 'danarchy_deploy/templater'
  require_relative 'danarchy_deploy/users'
  require_relative 'danarchy_deploy/version'
  require 'time'

  class LocalDeploy
    def self.new(deployment, options)
      puts "\n" + self.name
      puts "Pretend run! Not making any changes." if options[:pretend]
        
      puts 'Begining Deployment:'
      printf("%12s %0s\n", 'Hostname:', deployment[:hostname])
      printf("%12s %0s\n", 'OS:', deployment[:os])
      printf("%12s %0s\n", 'Packages:', deployment[:packages].join(', '))  if deployment[:packages]

      deployment = DanarchyDeploy::System.new(deployment, options)
      deployment = DanarchyDeploy::Services.new(deployment, options)
      deployment = DanarchyDeploy::Groups.new(deployment, options)
      deployment = DanarchyDeploy::Users.new(deployment, options)
      deployment = DanarchyDeploy::Services::Init.new(deployment, options)

      deployment[:last_deploy] = Time.now.strftime("%Y/%m/%d %H:%M:%S")
      puts "\nFinished Local Deployment at #{deployment[:last_deploy]}!"

      if options[:deploy_file].end_with?('.json')
        File.write(options[:deploy_file], JSON.pretty_generate(deployment))
      elsif options[:deploy_file].end_with?('.yaml') 
        File.write(options[:deploy_file], deployment.to_yaml)
      end

      deployment
    end
  end

  class RemoteDeploy
    def self.new(deployment, options)
      puts "\n" + self.name

      @working_dir = File.dirname(options[:deploy_file]) + '/'
      connector = { hostname: deployment[:hostname],
                    ipv4:     deployment[:ipv4],
                    ssh_user: deployment[:ssh_user],
                    ssh_key:  deployment[:ssh_key] }

      pretend = options[:pretend] ; options[:pretend] = false
      remote_mkdir(connector, options)
      # asdf_install(connector, options)

      if options[:dev_gem]
        puts "\nDev Gem mode: Building and pushing gem..."
        gem = dev_gem_build(options)
        dev_gem_install(connector, gem, options)
      else
        gem_install(connector, options)
      end

      gem_clean(connector, options)
      gem_binary = _locate_gem_binary(connector, options) # this should run before any install; check version too
      push_templates(connector, options)
      push_deployment(connector, options)

      options[:pretend] = pretend
      deploy_result = remote_LocalDeploy(connector, gem_binary, options)

      abort("\n ! Deployment failed to complete!") if !deploy_result

      pull_deployment(connector, options) if !options[:pretend]
      # remote_cleanup(connector, options) if !options[:pretend]

      puts "\nRemote deployment complete!"
      options[:deploy_file].end_with?('.json') ?
        JSON.parse(File.read(options[:deploy_file]), symbolize_names: true) :
        YAML.load_file(options[:deploy_file]) if options[:deploy_file].end_with?('.yaml')
    end

    private
    def self.remote_mkdir(connector, options)
      puts "\n > Creating directory: #{@working_dir}"
      mkdir_cmd = _ssh_command(connector, "test -d #{@working_dir} && echo 'Directory exists!' || sudo mkdir -vp #{@working_dir}")
      mkdir_result = DanarchyDeploy::Helpers.run_command(mkdir_cmd, options)

      if mkdir_result[:stderr] && ! mkdir_result[:stdout]
        abort('   ! Directory creation failed!')
      else
        puts "   |+ Created directory: '#{options[:deploy_dir]}'"
      end

      puts "\n > Setting directory permissions to '0750' for '#{connector[:ssh_user]}' on '#{options[:deploy_dir]}'"
      chown_cmd = _ssh_command(connector, "sudo chown -Rc #{connector[:ssh_user]}:#{connector[:ssh_user]} #{options[:deploy_dir]}; " +
                                          "sudo chmod -c 0750 #{options[:deploy_dir]}")
      chown_result = DanarchyDeploy::Helpers.run_command(chown_cmd, options)

      if chown_result[:stderr]
        abort('   ! Setting directory permissions failed!')
      else
        puts '   |+ Set directory permissions!'
      end
    end

    # def self.asdf_install(connector, options)
    #   versions = JSON.parse(
    #     File.read(File.expand_path('../', __dir__) + '/.asdf_versions.json'),
    #     symbolize_names: true)

    #   template = {
    #     target:    '/tmp/asdf.sh_' + Random.hex(6),
    #     source:    'builtin::asdf/asdf.sh.erb',
    #     variables: versions
    #   }

    #   DanarchyDeploy::Templater.new([template], options)
    #   push_cmd    = _scp_push(connector, template[:target], '/tmp')
    #   push_result = DanarchyDeploy::Helpers.run_command(push_cmd, options)

    #   if push_result[:stderr]
    #     abort('   ! Asdf push failed!')
    #   else
    #     puts '   |+ Asdf pushed!'
    #     asdf_chown_cmd    = _ssh_command(
    #       connector,
    #       "sudo mv -v #{template[:target]} /etc/profile.d/asdf.sh && " +
    #       'sudo chown -c root:root /etc/profile.d/asdf.sh')
    #     asdf_chown_result = DanarchyDeploy::Helpers.run_command(asdf_chown_cmd, options)
    #     File.delete(template[:target])
    #   end

    #   asdf_current_cmd    = _ssh_command(connector, 'sudo -i asdf current')
    #   asdf_current_result = DanarchyDeploy::Helpers.run_command(asdf_current_cmd, options)

    #   puts asdf_current_result[:stderr] if asdf_current_result[:stderr]
    #   puts asdf_current_result[:stdout]
    # end

    def self.gem_install(connector, options)
      puts "\n > Installing danarchy_deploy on #{connector[:hostname]}"
      install_cmd    = _ssh_command(connector, 'sudo -i gem install -f danarchy_deploy')
      install_result = DanarchyDeploy::Helpers.run_command(install_cmd, options)

      if install_result[:stderr] =~ /WARN/i
        puts '   ! ' + install_result[:stderr]
      elsif install_result[:stderr]
        abort('   ! Gem install failed!')
      else
        puts "   |+ Gem installed!"
      end
    end

    def self.dev_gem_build(options)
      gem = "danarchy_deploy-#{DanarchyDeploy::VERSION}.gem"
      puts "\n > Building gem: #{gem}"
      gem_dir = File.expand_path('../../', __FILE__)

      abort('ERROR: Need to be in development gem directory for --dev-gem!') if Dir.pwd != gem_dir
      
      gem_path = "#{gem_dir}/pkg/#{gem}"
      build_cmd = "cd #{gem_dir} && git add . && rake build"
      build_result = DanarchyDeploy::Helpers.run_command(build_cmd, options)

      if build_result[:stderr]
        abort('   ! Gem build failed!')
      elsif File.exist?(gem_path)
        puts "   |+ Gem built: #{gem_path}"
      end

      gem_path
    end

    def self.dev_gem_install(connector, gem, options)
      puts "\n > Pushing gem: #{gem} to #{connector[:hostname]}"
      push_cmd    = _scp_push(connector, gem, options[:deploy_dir])
      push_result = DanarchyDeploy::Helpers.run_command(push_cmd, options)

      if push_result[:stderr]
        abort('   ! Gem push failed!')
      else
        puts '   |+ Gem pushed!'
      end
      
      puts "\n > Installing gem: #{gem} on #{connector[:hostname]}"
      install_cmd    = _ssh_command(connector, "sudo -i gem install --bindir /usr/local/bin -f #{options[:deploy_dir]}/#{File.basename(gem)}")
      install_result = DanarchyDeploy::Helpers.run_command(install_cmd, options)

      if install_result[:stderr] =~ /WARN/i
        puts '   ! ' + install_result[:stderr]
      elsif install_result[:stderr]
        abort('   ! Gem install failed!')
      else
        puts '   |+ Gem installed!'
      end
    end

    def self.gem_clean(connector, options)
      clean_cmd = _ssh_command(connector, 'sudo -i gem clean danarchy_deploy 2&>/dev/null')
      system(clean_cmd)
    end

    def self.push_templates(connector, options)
      template_dir = options[:deploy_dir] + '/templates'
      puts "\n > Pushing templates: #{template_dir}"
      push_cmd    = _rsync_push(connector, template_dir, template_dir)
      push_result = DanarchyDeploy::Helpers.run_command(push_cmd, options)
      
      if push_result[:stderr]
        abort('   ! Templates push failed!')
      else
        puts "   |+ Templates pushed to '#{template_dir}'!"
      end
    end

    def self.push_deployment(connector, options)
      puts "\n > Pushing deployment: #{options[:deploy_file]}"
      push_cmd    = _rsync_push(connector, @working_dir, @working_dir)
      push_result = DanarchyDeploy::Helpers.run_command(push_cmd, options)

      if push_result[:stderr]
        abort('   ! Deployment push failed!')
      else
        puts "   |+ Deployment pushed to '#{@working_dir}'!"
      end
    end

    def self.remote_LocalDeploy(connector, gem_binary, options)
      puts "\n > Running LocalDeploy on #{connector[:hostname]}.\n\n"

      deploy_cmd  = "sudo -i #{gem_binary} local "
      deploy_cmd += '--first-run '    if options[:first_run]
      deploy_cmd += '--ssh-verbose '  if options[:ssh_verbose]
      deploy_cmd += '--vars-verbose ' if options[:vars_verbose]
      deploy_cmd += '--pretend '      if options[:pretend]
      deploy_cmd += '--json '         if options[:deploy_file].end_with?('.json')
      deploy_cmd += '--yaml '         if options[:deploy_file].end_with?('.yaml')
      deploy_cmd += options[:deploy_file]

      deploy_command = _ssh_command(connector, deploy_cmd)
      system(deploy_command)
    end

    def self.pull_deployment(connector, options)
      puts "\n > Pulling deployment: #{options[:deploy_file]}"
      pull_cmd = _scp_pull(connector, options[:deploy_file], options[:deploy_file])
      pull_result = DanarchyDeploy::Helpers.run_command(pull_cmd, options)
      
      if pull_result[:stderr]
        abort('   ! Deployment pull failed!')
      else
        puts "   |+ Deployment pulled!"
      end
    end

    def self.remote_cleanup(connector, options)
      puts "\n > Cleaning up: #{options[:deploy_dir]}"
      cleanup_cmd    = _ssh_command(connector, "sudo rm -rfv #{@working_dir}")
      cleanup_result = DanarchyDeploy::Helpers.run_command(cleanup_cmd, options)

      if cleanup_result[:stderr]
        abort('   ! Deployment cleanup failed!')
      else
        puts "   |+ Deployment cleaned up!"
      end
    end

    def self._locate_gem_binary(connector, options)
      locate_cmd    = _ssh_command(connector, 'sudo -i which danarchy_deploy')
      locate_result = DanarchyDeploy::Helpers.run_command(locate_cmd, options)

      if locate_result[:stderr]
        abort('   ! Could not locate Ruby gem binary!')
      else
        puts '   |+ Gem binary located!'
      end

      locate_result[:stdout].chomp
    end

    def self._ssh_command(connector, command)
      "ssh -i #{connector[:ssh_key]} " +
        "#{connector[:ssh_user]}@#{connector[:ipv4]} " +
        "-o ConnectTimeout=30 -o StrictHostKeyChecking=no '#{command}'"
    end

    def self._scp_push(connector, local, remote)
      "scp -i #{connector[:ssh_key]} #{local} #{connector[:ssh_user]}@#{connector[:ipv4]}:#{remote}/"
    end

    def self._scp_pull(connector, remote, local)
      "scp -i #{connector[:ssh_key]} #{connector[:ssh_user]}@#{connector[:ipv4]}:#{remote} #{local}"
    end

    def self._rsync_push(connector, local, remote)
      "rsync --rsh 'ssh -i #{connector[:ssh_key]}' -Havzu --delete #{local}/ #{connector[:ssh_user]}@#{connector[:ipv4]}:#{remote}/"
    end

    def self._rsync_pull(connector, remote, local)
      "rsync --rsh 'ssh -i #{connector[:ssh_key]}' -Havzu --delete #{connector[:ssh_user]}@#{connector[:ipv4]}:#{remote}/ #{local}/"
    end
  end
end
