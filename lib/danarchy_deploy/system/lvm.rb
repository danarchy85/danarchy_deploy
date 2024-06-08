
module DanarchyDeploy
  module System
    module Mounts
      module Lvm
        attr_reader :name
        attr_reader :vg
        attr_reader :pv

        def self.new(os, lvm, options)
          puts "\n > Configuring LVM"
          @name, @vg, @pv = device.to_s.split(/:/)
          pvdisplay = pv_create
          vgdisplay = vg_create
          lvdisplay = lv_create
          enable_lvm
          [pvdisplay, vgdisplay, lvdisplay]
        end

        private
        def self.enable_lvm
          service = os == 'gentoo' ? 'dmcrypt' : 'cryptsetup'
          %w[enable start].each do |action|
            DanarchyDeploy::Services::Init.init_manager(os, service, action, options)
          end
        end

        def self.pv_create # (device, volume, options)
          # Create physical volume
          pvdisplay = DanarchyDeploy::Helpers.run_command("pvdisplay #{@pv}", options)
          if pvdisplay[:stderr]
            puts "Creating physical volume: #{@pv}"
            pvcreate = DanarchyDeploy::Helpers.run_command("pvcreate -f #{@pv}", options)
            abort("   ! Failed to run pvcreate: #{@pvcreate[:stderr]}") if pvcreate[:stderr]
            puts pvcreate[:stdout]
            pvdisplay = DanarchyDeploy::Helpers.run_command("pvdisplay #{@pv}", options)
          end
          puts pvdisplay[:stderr] || pvdisplay[:stdout]

          pvdisplay
        end

        def self.vg_create
          # Create volume group
          vgdisplay = DanarchyDeploy::Helpers.run_command("vgdisplay #{@vg}", options)
          if vgdisplay[:stderr]
            puts "Creating volume group: #{@vg} with #{pv}"
            vgcreate = DanarchyDeploy::Helpers.run_command("vgcreate #{@vg} #{pv}", options)
            abort("   ! Failed to run vgcreate: #{@vgcreate[:stderr]}") if vgcreate[:stderr]
            puts vgcreate[:stdout]
            vgdisplay = DanarchyDeploy::Helpers.run_command("vgdisplay #{@vg}", options)
          end
          puts vgdisplay[:stderr] || vgdisplay[:stdout]

          vgdsplay
        end

        def self.lv_create
          # Create logical volume
          lvdisplay = DanarchyDeploy::Helpers.run_command("lvdisplay #{@vg}/#{name}", options)
          if lvdisplay[:stderr]
            puts "Creating volume group: #{@vg}/#{name} with #{pv}"
            lvcreate = DanarchyDeploy::Helpers.run_command("lvcreate -y -l 100%FREE -n #{name} #{@vg}", options)
            abort("   ! Failed to run lvcreate: #{lvcreate[:stderr]}") if lvcreate[:stderr]
            puts lvcreate[:stdout]
            lvdisplay = DanarchyDeploy::Helpers.run_command("lvdisplay #{@vg}/#{name}", options)
          end
          puts lvdisplay[:stderr] || lvdisplay[:stdout]

          lvdisplay
        end
      end
    end
  end
end
