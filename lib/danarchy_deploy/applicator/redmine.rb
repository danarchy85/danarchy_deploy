
module DanarchyDeploy
  module Applicator
    module Redmine
      def self.new(app, options)
        puts "\n" + self.name
        puts " > Checking on Redmine installation at #{app[:path]}"

        repo = 'https://svn.redmine.org/redmine/branches/' + app[:version]
      end

      private
      def self.cmd_prefix(app)
        
      end

      def self.redmine_version(app)
        version = []
        version_rb = File.readlines(app[:path] + '/lib/redmine/version.rb')
        version_rb.grep(/(MAJOR|MINOR|TINY)\s+=/).each do |v|
          v = v.chomp.gsub!(/\s+/, '')
          version.push(v.split(/=/).last)
        end

        version.join('.')
      end

      def self.database_yml(app)
        dbs = app[:database]
        dbs.each do |db, values|
          values[:adapter] = values[:adapter] ? values[:adapter] : 'mysql2'
          values[:encoding] = values[:encoding] ? values[:encoding] : 'utf8'
        end

        db_yml = app[:path] + '/config/database.yml'
        File.write(db_yml, dbs.to_yaml)
      end
    end
  end
end
