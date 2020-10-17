
module DanarchyDeploy
  module System
    class Gentoo
      def self.new(deployment, options)
        puts "\n" + self.name
        puts 'Gentoo detected! Using emerge.'

        hostname = deployment[:hostname]
        if check_hostname(hostname) == false
          puts "Setting hostname to: #{hostname}"
          set_hostname(hostname)
        end

        installer  = 'emerge --usepkg --buildpkg --quiet --noreplace '
        # This needs cpuid2cpuflags to build make.conf; don't --pretend here.
        system("qlist -I cpuid2cpuflags &>/dev/null || #{installer} cpuid2cpuflags &>/dev/null")
        installer += '--pretend ' if options[:pretend]

        updater  = 'emerge --usepkg --buildpkg --update --deep --newuse --quiet --with-bdeps=y @world'
        updater += ' --pretend' if options[:pretend]

        cleaner  = 'emerge --depclean --quiet '
        cleaner += '--pretend ' if options[:pretend]

        if deployment[:portage]
          if deployment[:portage][:templates]
            puts "\nChecking Portage configs."
            DanarchyDeploy::Templater.new(deployment[:portage][:templates], options)
          end

          emerge_sync(options) if deployment[:portage][:sync]
        end

        [installer, updater, cleaner]
      end

      private

      def self.emerge_sync(options)
        File.open('/tmp/datetime', 'a+') do |f|
          last_sync = f.getbyte ? DateTime.parse(f.read) : (DateTime.now - 2)

          if (DateTime.now - last_sync).to_i != 0
            puts "\nUpdating Portage repo..."
            DanarchyDeploy::Helpers.run_command('emerge --sync --quiet 2>/dev/null', options)
            f.truncate(0)
            f.write DateTime.now
          end

          f.close
        end
      end

      def self.set_hostname(hostname)
        confd_hostname = "hostname=\"#{hostname}\""
        File.write('/etc/conf.d/hostname', confd_hostname)
        `hostname #{hostname}`
      end

      def self.check_hostname(hostname)
        `hostname`.chomp == hostname
      end
    end
  end
end
