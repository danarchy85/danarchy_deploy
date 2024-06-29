
module DanarchyDeploy
  class Users
    def self.new(deployment, options)
      return deployment if ! deployment[:users]
      puts "\n" + self.name
      (useradd_result, userdel_result, archives_result) = nil

      deployment[:users].each do |username, user|
        user[:username] = username.to_s
        puts "\n > Checking if user '#{user[:username]}' already exists."
        usercheck_result = usercheck(user, options)

        if usercheck_result[:stdout]
          puts "   - User: #{user[:username]} already exists!"
        else
          group = { groupname: user[:username] }
          group[:gid]    = user[:gid]    || nil
          group[:system] = user[:system] || nil

          groupcheck_result = DanarchyDeploy::Groups.groupcheck(group, options)
          if !groupcheck_result[:stdout] && group[:gid]
            puts "   |+ Adding group: #{group[:groupname]}"
            DanarchyDeploy::Groups.groupadd(group, options)
          end

          puts "   |+ Adding user: #{user[:username]}"
          useradd_result = useradd(user, options)
          File.chmod(0750, user[:home]) if Dir.exist?(user[:home])
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
            sudoer(user, options)
          end
        end

        if user[:applications]
          puts "\n > Checking #{user[:username]}'s applications."
          user = DanarchyDeploy::Applicator.new(deployment[:os], user, options)
        end

        user.delete(:username)
      end

      deployment
    end

    private
    def self.useradd(user, options)
      useradd_cmd  = "useradd #{user[:username]} "
      useradd_cmd += "--home-dir #{user[:home]} "           if user[:home]
      useradd_cmd += "--create-home "                       if !Dir.exist?(user[:home])
      useradd_cmd += "--uid #{user[:uid]} "                 if user[:uid]
      useradd_cmd += "--gid #{user[:gid]} "                 if user[:gid]
      useradd_cmd += "--groups #{user[:groups].join(',')} " if user[:groups]
      useradd_cmd += "--shell /sbin/nologin "               if user[:nologin]
      useradd_cmd += "--system "                            if user[:system]
      DanarchyDeploy::Helpers.run_command(useradd_cmd, options)
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
      DanarchyDeploy::Helpers.run_command(groupupdate_cmd, options)
    end

    def self.add_to_group(user, options)
      groups = user[:groups].join(',')
      groupadd_cmd = "usermod #{user[:username]} --groups #{groups} --append"
      DanarchyDeploy::Helpers.run_command(groupadd_cmd, options)
    end

    def self.remove_from_group(user, group, options)
      groups = user[:groups].join(',')
      removegroup_cmd = "gpasswd --remove #{user[:username]} #{group}"
      DanarchyDeploy::Helpers.run_command(removegroup_cmd, options)
    end

    def self.authorized_keys(user, options)
      templates = [
        {
          source: 'builtin::system/authorized_keys.erb',
          target: user[:home] + '/.ssh/authorized_keys',
          dir_perms: {
            owner: user[:username],
            group: user[:username],
            mode:  '0700'
          },
          file_perms: {
            owner: user[:username],
            group: user[:username],
            mode:  '0644'
          },
          variables: {
            authorized_keys: user[:ssh_authorized_keys]
          }
        }
      ]

      DanarchyDeploy::Templater.new(templates, options)

      # ssh_path = user[:home] + '/.ssh'
      # authkeys = ssh_path + '/authorized_keys'

      # Dir.exist?(ssh_path) || Dir.mkdir(ssh_path, 0700)
      # File.chown(user[:uid], user[:gid], ssh_path)
      # File.open(authkeys, 'a+') do |f|
      #   contents = f.read
      #   user[:authorized_keys].each do |authkey|
      #     if contents.include?(authkey)
      #       puts "   - Key already in place: #{authkey}"
      #     else
      #       puts "   + Adding authorized_key: #{authkey}"
      #       f.puts authkey
      #     end
      #   end

      #   f.chown(user[:uid], user[:gid])
      #   f.close
      # end
    end

    def self.sudoer(user, options)
      templates = [
        {
          source: 'builtin::system/sudoers.erb',
          target: '/etc/sudoers.d/danarchy_deploy-' + user[:username],
          file_perms: {
            owner: 'root',
            group: 'root',
            mode: '0440'
          },
          variables: {
            rules: user[:sudoer]
          }
        }
      ]

      DanarchyDeploy::Templater.new(templates, options)
    end
  end
end
