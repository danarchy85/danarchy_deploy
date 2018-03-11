
module DanarchyDeploy
  class Users
    def self.new(deployment, options)
      puts "\n" + self.name
      (useradd_result, userdel_result, archives_result) = nil

      deployment[:users].each do |user|
        puts " > Checking if user '#{user[:username]}' already exists."
        usercheck_result = usercheck(user, options)

        if usercheck_result[:stdout]
          puts "   - User: #{user[:username]} already exists!"
        else
          group = { groupname: user[:username] }
          group[:gid] = user[:gid] ? user[:gid] : nil
          group[:system] = user[:system] ? user[:system] : nil

          groupcheck_result = DanarchyDeploy::Groups.groupcheck(group, options)
          if !groupcheck_result[:stdout] && group[:gid]
            puts "   |+ Adding group: #{group[:groupname]}"
            DanarchyDeploy::Groups.groupadd(group, options)
          end

          puts "   |+ Adding user: #{user[:username]}"
          useradd_result = useradd(user, options)
        end

        if !options[:pretend]
          puts "\n > Checking groups for user: #{user[:username]}"
          if user[:groups] && checkgroups(usercheck_result, user, options) == false
            updategroups(user, options)
            puts "   |+ Updated groups: #{user[:groups].join(',')}"
          else
            puts "   - No change to groups needed."
          end

          if user[:authorized_keys]
            puts "\n > Checking on #{user[:authorized_keys].count} authorized_keys for user: #{user[:username]}"
            authorized_keys(user)
          end
          
          if user[:sudoer]
            puts "\n > Checking sudo rules for user: #{user[:username]}"
            sudoer(user)
          end
        end

        if user[:archives] && !user[:archives].empty?
          puts " > Deploying archives for #{user[:username]}"
          DanarchyDeploy::Archiver.new(user[:archives], options)
        end
      end

      # [useradd_result, userdel_result]
      deployment
    end

    private
    def self.useradd(user, options)
      useradd_cmd  = "useradd #{user[:username]} "
      useradd_cmd += "--home-dir #{user[:home]} " if user[:home]
      useradd_cmd += "--uid #{user[:uid]} " if user[:uid]
      useradd_cmd += "--gid #{user[:gid]} " if user[:gid]
      useradd_cmd += "--groups #{user[:groups].join(',')} " if user[:groups]
      useradd_cmd += "--shell /sbin/nologin " if user[:nologin]
      useradd_cmd += "--system " if user[:system]
      if options[:pretend]
        puts "\tFake run: #{useradd_cmd}"
      else
        DanarchyDeploy::Helpers.run_command(useradd_cmd, options)
      end
    end

    def self.userdel(user, options)
      userdel_cmd  = "userdel --remove #{user[:username]}"
      if options[:pretend]
        puts "\tFake run: #{userdel_cmd}"
      else
        DanarchyDeploy::Helpers.run_command(userdel_cmd, options)
      end
    end

    def self.usercheck(user, options)
      DanarchyDeploy::Helpers.run_command("id #{user[:username]}", options)
    end

    def self.checkgroups(usercheck_result, user, options)
      return nil if !usercheck_result[:stdout]
      livegroups = usercheck_result[:stdout].split(/\s+/).last.split('=').last.gsub(/\(([^)]*)\)/, '').split(',').map(&:to_i)
      livegroups.delete(user[:gid])
      livegroups.sort == user[:groups].sort
    end

    def self.updategroups(user, options)
      groups = user[:groups].join(',')
      groupupdate_cmd = "usermod #{user[:username]} --groups #{groups}"
      if options[:pretend]
        puts "\tFake run: #{groupupdate_cmd}"
      else
        DanarchyDeploy::Helpers.run_command(groupupdate_cmd, options)
      end
    end

    def self.authorized_keys(user)
      ssh_path = user[:home] + '/.ssh'
      authkeys = ssh_path + '/authorized_keys'

      Dir.exist?(ssh_path) || Dir.mkdir(ssh_path, 0700)
      File.chown(user[:uid], user[:gid], ssh_path)
      File.open(authkeys, 'a+') do |f|
        user[:authorized_keys].each do |authkey|
          if !f.read.include?(authkey)
            puts "   + Adding authorized_key: #{authkey}"
            f.puts authkey
          else
            puts '   - No change needed'
          end
        end

        f.close
      end
    end

    def self.sudoer(user)
      sudoer_file = '/etc/sudoers.d/danarchy_deploy-' + user[:username]
      File.open(sudoer_file, 'a+') do |f|
        if !f.read.include?(user[:sudoer])
          puts "   |+ Added: '#{user[:sudoer]}'"
          f.puts user[:sudoer]
        else
          puts '   - No change needed'
        end

        f.chown(user[:uid], user[:gid])
        f.close
      end
    end
  end
end
