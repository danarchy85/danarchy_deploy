require 'securerandom'
require_relative 'services/init'
require_relative 'services/mongodb'
require_relative 'services/mysql'

module DanarchyDeploy
  module Services
    def self.new(deployment, options)
      return deployment if ! deployment[:services]
      puts "\n" + self.name

      deployment[:services].each do |service, params|
        puts "\nConfiguring service: #{service}"

        if params[:archives] && !params[:archives].empty?
          puts "\n" + self.name
          puts " > Deploying archives for #{service}"
          DanarchyDeploy::Archiver.new(params[:archives], options)
        end

        if params[:templates] && !params[:templates].empty?
          puts " > Configuring templates for #{service}"
          DanarchyDeploy::Templater.new(params[:templates], options)
        end

        if %w[mysql mariadb].include?(service.to_s)
          DanarchyDeploy::Services::MySQL.new(deployment[:os], params, options)
        end

        if %[mongodb].include?(service.to_s)
          DanarchyDeploy::Services::MongoDB.new(deployment[:os], params, options)
        end
      end

      deployment
    end
  end
end
