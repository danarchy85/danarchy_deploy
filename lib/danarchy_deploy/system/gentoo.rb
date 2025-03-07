
module DanarchyDeploy
  module System
    class Gentoo
      def self.new(deployment, options)
        puts "\n" + self.name
        puts 'Gentoo detected! Using emerge.'

        set_hostname(deployment[:hostname]) if !options[:pretend]
        installer  = 'emerge --usepkg --buildpkg --quiet --noreplace '
        # This needs cpuid2cpuflags to build make.conf; don't --pretend here.
        system("qlist -I cpuid2cpuflags &>/dev/null || #{installer} cpuid2cpuflags &>/dev/null")
        installer += '--pretend ' if options[:pretend]

        updater  = 'emerge --usepkg --buildpkg --update --deep --newuse --quiet --with-bdeps=y @world'
        updater += ' --pretend' if options[:pretend]

        cleaner  = 'emerge --depclean --quiet '
        cleaner += '--pretend ' if options[:pretend]

        if emerge_sync_in_progress
          puts "\n >  Waiting for emerge sync to complete."
          emerge_sync_wait
        end

        if deployment[:portage]
          if deployment[:portage][:templates]
            puts "\nChecking Portage configs."
            DanarchyDeploy::Templater.new(deployment[:portage][:templates], options)
          end

          emerge_sync(deployment[:portage][:sync], options)
        end

        [installer, updater, cleaner]
      end

      private
      def self.emerge_sync_in_progress
        @repo_path = `emerge --info | grep location`.chomp.split(': ').last
        Dir.exist?(@repo_path + '/.tmp-unverified-download-quarantine')
      end

      def self.emerge_sync_wait
        while emerge_sync_in_progress
          sleep 3
        end
        puts "     |> Continuing with emerge!"
      end

      def self.emerge_sync(sync, options)
        puts "\n >  Gentoo Emerge Sync"
        if sync.nil?
          install_sync_cron(sync, options)
        elsif sync == false
          puts "\n   - Not running emerge sync; set to: #{sync}"
          install_sync_cron(sync, options)
        elsif sync == true
          File.delete('/var/spool/cron/crontabs/portage') if File.exist?('/var/spool/cron/crontabs/portage')
          begin
            DanarchyDeploy::Helpers.run_command('emerge --sync &>/var/log/emerge-sync.log', options)
          ensure
            if Dir.exist?("#{@repo_path}/.tmp-unverified-download-quarantine")
              puts "\n    ! emerge --sync may have failed: cleaning up tmp path."
              DanarchyDeploy::Helpers.run_command("rm -rf #{@repo_path}/.tmp-unverified-download-quarantine", options)
            end
          end
        elsif sync =~ /([0-9]{1,2}|\*|\@[a-z]{4,7})/i
          install_sync_cron(sync, options)
        else
          puts "\n   ! Unknown sync cron time: #{sync}. Not running emerge sync!"
        end
      end

      def self.set_hostname(hostname)
        if `hostname`.chomp != hostname
          puts "Setting hostname to: #{hostname}"
          confd_hostname = "hostname=\"#{hostname}\""
          File.write('/etc/conf.d/hostname', confd_hostname)
          `hostname #{hostname}`
        end
      end

      def self.install_sync_cron(sync, options)
        templates = Array.new
        if sync.nil? || sync == false
          DanarchyDeploy::Helpers.run_command(
            'id portage | grep cron >/dev/null && usermod -r -G cron portage',
            options)

          templates.push({ target: '/etc/cron.daily/portage_sync.sh',
                           remove: true })
        else
          DanarchyDeploy::Helpers.run_command(
            'id portage | grep cron >/dev/null || usermod -a -G cron portage',
            options)

          templates.push({ source: 'builtin::portage/portage_sync.sh',
                           target: '/etc/cron.daily/portage_sync.sh',
                           file_perms: {
                             owner: 'root',
                             group: 'root',
                             mode: '0740'
                           }
                         })
        end

        DanarchyDeploy::Templater.new(templates, options)
      end
    end
  end
end
