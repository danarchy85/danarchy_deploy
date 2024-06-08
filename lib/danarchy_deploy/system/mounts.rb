require_relative './mounts/cryptsetup.rb'
require_relative './mounts/fstab.rb'
require_relative './mounts/lvm.rb'

module DanarchyDeploy
  module System
    module Mounts
      def self.new(os, mounts, options)
        mounts.each do |mount|
          
        end
      end
    end
  end
end
