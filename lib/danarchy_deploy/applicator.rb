require_relative 'applicator/wordpress'
require_relative 'applicator/nginx'
require_relative 'applicator/phpfpm'
require_relative 'applicator/ssl'

module DanarchyDeploy
  module Applicator
    def self.new(os, user, options)
      puts "\n" + self.name

      user[:applications].each do |domain, app|
        app[:domain] = domain.to_s
        app[:username] = user[:username]
        app[:path] = app[:path] ? app[:path] : user[:home] + '/' + app[:domain]

        Dir.exist?(app[:path]) || FileUtils.mkdir_p(app[:path], mode: 0755)
        FileUtils.chown_R(user[:username], user[:username], app[:path])

        if app[:archives] && options[:first_run]
          puts "\n > Deploying archives for #{domain}"
          perms = { uid: user[:uid], gid: user[:gid] }
          app[:archives].map{|a| a[:perms] = perms }
          puts "\n   |> Applying user's ownership to archives: #{perms}"
          DanarchyDeploy::Archiver.new(app[:archives], options)
        end

        app = DanarchyDeploy::Applicator::PHPFPM.new(app, options)    if app[:phpfpm]
        app = DanarchyDeploy::Applicator::Nginx.new(app, options)     if app[:nginx]
        app = DanarchyDeploy::Applicator::WordPress.new(app, options) if app[:app] == 'wordpress'
        app = DanarchyDeploy::Applicator::Redmine.new(app, options)   if app[:app] == 'redmine'

        app.delete_if { |k, v| [:username, :domain].include? k }
        user[:applications][domain] = app
      end

      user
    end
  end
end
