
module DanarchyDeploy
  module System
    class Cryptsetup
      def self.new(os, cryptsetup, options)
        return false if cryptsetup.nil?
        
        # expects object: { "cryptsetup": { "source": "/danarchy/deploy/templates/system/cryptsetup.erb", (optional)
        #                                "volumes": { "vg_name:vg0:/dev/vdb": { "target": "dm-vg0-mongodb",
        #                                                               "source": "/dev/mapper/vg0-mongodb",
        #                                                               "key": "/root/vdb_mongodb.key" } } } }

        if os == 'gentoo'
          DanarchyDeploy::Services::Init.init_manager(os, 'lvmetad', 'enable', options)
          DanarchyDeploy::Services::Init.init_manager(os, 'lvmetad', 'start', options)
        end

        service, target, source = set_config(cryptsetup, options)
        lvm_result, crypt_result = nil
        cryptsetup[:volumes].each do |device, volume|
          lvm_result   = lvm_setup(device, volume, options)
          crypt_result = encrypt_volume(volume, options)
        end

        deploy_template(target, source, cryptsetup[:volumes], options)
        if os == 'gentoo'
          DanarchyDeploy::Services::Init.init_manager(os, service, 'enable', options)
          DanarchyDeploy::Services::Init.init_manager(os, service, 'restart', options)
        end
      end

      private
      def self.set_config(cryptsetup, options)
        service, target = File.exist?('/etc/conf.d/dmcrypt') ?
                            ['dmcrypt','/etc/conf.d/dmcrypt'] :
                            ['cryptsetup','/etc/crypttab']

        source = if cryptsetup[:source]
                   cryptsetup[:source]
                 elsif target == '/etc/conf.d/dmcrypt'
                   options[:deploy_dir] + '/templates/system/dmcrypt.erb'
                 elsif target == '/etc/crypttab'
                   options[:deploy_dir] + '/templates/system/crypttab.erb'
                 else
                   nil
                 end

        [service, target, source]
      end

      def self.lvm_setup(device, volume, options)
        name, vg, pv = device.to_s.split(/:/)

        # Create physical volume
        pvdisplay = DanarchyDeploy::Helpers.run_command("pvdisplay #{pv}", options)
        if pvdisplay[:stderr]
          puts "Creating physical volume: #{pv}"
          pvcreate = DanarchyDeploy::Helpers.run_command("pvcreate -f #{pv}", options)
          abort("  ! Failed to run pvcreate: #{pvcreate[:stderr]}") if pvcreate[:stderr]
          puts pvcreate[:stdout]
          pvdisplay = DanarchyDeploy::Helpers.run_command("pvdisplay #{pv}", options)
        end
        puts pvdisplay[:stderr] || pvdisplay[:stdout]

        # Create volume group
        vgdisplay = DanarchyDeploy::Helpers.run_command("vgdisplay #{vg}", options)
        if vgdisplay[:stderr]
          puts "Creating volume group: #{vg} with #{pv}"
          vgcreate = DanarchyDeploy::Helpers.run_command("vgcreate #{vg} #{pv}", options)
          abort("  ! Failed to run vgcreate: #{vgcreate[:stderr]}") if vgcreate[:stderr]
          puts vgcreate[:stdout]
          vgdisplay = DanarchyDeploy::Helpers.run_command("vgdisplay #{vg}", options)
        end
        puts vgdisplay[:stderr] || vgdisplay[:stdout]

        # Create logical volume
        lvdisplay = DanarchyDeploy::Helpers.run_command("lvdisplay #{vg}/#{name}", options)
        if lvdisplay[:stderr]
          puts "Creating volume group: #{vg}/#{name} with #{pv}"
          lvcreate = DanarchyDeploy::Helpers.run_command("lvcreate -y -l 100%FREE -n #{name} #{vg}", options)
          abort("  ! Failed to run lvcreate: #{lvcreate[:stderr]}") if lvcreate[:stderr]
          puts lvcreate[:stdout]
          lvdisplay = DanarchyDeploy::Helpers.run_command("lvdisplay #{vg}/#{name}", options)
        end
        puts lvdisplay[:stderr] || lvdisplay[:stdout]

        [pvdisplay, vgdisplay, lvdisplay]
      end

      def self.encrypt_volume(volume, options)
        deploy_key(volume, options)
        target = volume[:variables][:target]
        source = volume[:variables][:source]
        key    = volume[:variables][:key]
        abort(" Failed to find key: #{key}") if !File.exist?(key) && !options[:pretend]
        
        # Encrypt logical volume with key
        luksdump = DanarchyDeploy::Helpers.run_command("cryptsetup luksDump #{source}", options)
        if luksdump[:stderr]
          puts "Encrypting volume: #{source}"
          luksformat = DanarchyDeploy::Helpers.run_command("cryptsetup luksFormat #{source} #{key}", options)
          abort("  ! Failed to run luksFormat: #{luksformat[:stderr]}") if luksformat[:stderr]
          puts luksformat[:stdout]
          luksdump = DanarchyDeploy::Helpers.run_command("cryptsetup luksDump #{source}", options)
        end
        puts luksdump[:stderr] || luksdump[:stdout]

        # Open luks target
        luksopen = { stderr: nil }
        if !File.exist?("/dev/mapper/#{target}")
          puts "Opening volume: #{source}"
          luksopen = DanarchyDeploy::Helpers.run_command("cryptsetup luksOpen -d #{key} #{source} #{target}", options)
          abort("  ! Failed to run luksOpen: #{luksopen[:stderr]}") if luksopen[:stderr]
          puts luksopen[:stdout]
        end

        [luksdump, luksopen]
      end

      def self.deploy_key(volume, options)
        templates = [{ source: volume[:key_file],
                       target: volume[:variables][:key],
                       file_perms: {
                         owner: 'root',
                         group: 'root',
                         mode:  '0400' } }]
        
        DanarchyDeploy::Templater.new(templates, options)
      end

      def self.deploy_template(target, source, volumes, options)
        templates = [{ target: target, source: source, variables: volumes }]
        DanarchyDeploy::Templater.new(templates, options)
      end
    end
  end
end
