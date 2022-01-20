
module DanarchyDeploy
  module System
    class Fstab
      def self.new(os, fstab, options)
        puts "\n" + self.name
        target, source = set_config(fstab, options)
        deploy_template(target, source, fstab[:mounts], options)
        format_mountpoints(fstab, options)
        mount_all(options)
      end

      private
      def self.set_config(fstab, options)
        target = '/etc/fstab'
        source = fstab[:source] ?
                   fstab[:source] :
                   '/danarchy/deploy/templates/system/fstab.erb'

        [target, source]
      end

      def self.deploy_template(target, source, mounts, options)
        templates = [{ target: target,
                       source: source,
                       variables: mounts }]

        DanarchyDeploy::Templater.new(templates, options)
      end

      def self.format_mountpoints(fstab, options)
        return false if fstab.nil?
        puts "\n > Formatting mountpoints"

        fstab[:mounts].each do |mount|
          fs_check = DanarchyDeploy::Helpers.run_command(
            "file -sL #{mount[:filesystem]}", options
          )

          if fs_check[:stdout] && fs_check[:stdout] =~ /.*data$/
            puts "\n   > Formatting #{mount[:filesystem]}"
            mkfs = DanarchyDeploy::Helpers.run_command(
              "mkfs -t #{mount[:type]} #{mount[:filesystem]}", options
            )
            abort("    ! Failed to run mkfs: #{mkfs[:stderr]}") if mkfs[:stderr]
          end

          FileUtils.mkdir_p(mount[:mountpoint]) if !options[:pretend] &&
                                                   !Dir.exist?(mount[:mountpoint])
        end
      end

      def self.mount_all(options)
        puts "\n > Mounting Filesystems"
        mount_result = DanarchyDeploy::Helpers.run_command('mount -a', options)
        abort('    ! Failed to mount filesystems!') if mount_result[:stderr]
      end
    end
  end
end
