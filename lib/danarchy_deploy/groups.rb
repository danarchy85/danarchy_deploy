
module DanarchyDeploy
  class Groups
    def self.new(deployment, options)
      puts "\n" + self.name
      (groupadd_result, groupdel_result) = nil

      deployment[:groups].each do |group|
        puts " > Checking if group '#{group[:groupname]}' already exists."
        groupcheck_result = groupcheck(group, options)

        if groupcheck_result[:stdout]
          puts "   - Group: #{group[:groupname]} already exists!"
        else
          puts "   |+ Adding group: #{group[:groupname]}"
          groupadd_result = groupadd(group, options)
        end
      end

      # [groupadd_result, groupdel_result]
      deployment
    end

    private
    def self.groupadd(group, options)
      groupadd_cmd  = "groupadd #{group[:groupname]} "
      groupadd_cmd += "--gid #{group[:gid]} " if group[:gid]
      groupadd_cmd += "--system " if group[:system]
      if options[:pretend]
        puts "\tFake run: #{groupadd_cmd}"
      else
        DanarchyDeploy::Helpers.run_command(groupadd_cmd, options)
      end
    end

    def self.groupdel(group, options)
      groupdel_cmd = "groupdel #{group[:groupname]}"
      if options[:pretend]
        puts "\tFake run: #{groupdel_cmd}"
      else
        DanarchyDeploy::Helpers.run_command(groupdel_cmd, options)
      end
    end

    def self.groupcheck(group, options)
      DanarchyDeploy::Helpers.run_command("/usr/bin/getent group #{group[:groupname]}", options)
    end
  end
end
