require 'mongo'

module DanarchyDeploy
  module Services
    class MongoDB
      def self.new(os, mongodb, options)
        @mongodb = mongodb
        @options = options
        puts "\n" + self.name
        puts "\n > Configuring MongoDB service."

        DanarchyDeploy::Services::Init.init_manager(os, 'mongodb', 'start', options) if ! options[:pretend]
        Mongo::Logger.logger.level = Logger::FATAL
        mongodb_conf, updated_conf = self.load_mongodb_conf
        host_port = mongodb_conf['net']['bindIp'].split(',').first + ':' + mongodb_conf['net']['port'].to_s
        admin_user, new_admin   = self.load_admin_user

        if new_admin == true
          client = Mongo::Client.new(['127.0.0.1'], database: 'admin')
          self.ensure_user(client.database, admin_user)
        end

        if ! options[:pretend] && updated_conf == true || new_admin == true
          puts 'Stopping MongoDB'
          DanarchyDeploy::Services::Init.init_manager(os, 'mongodb', 'stop', options)
          self.save_mongodb_conf(mongodb_conf)
          puts 'Starting MongoDB'
          DanarchyDeploy::Services::Init.init_manager(os, 'mongodb', 'start', options)
        end

        client = Mongo::Client.new([host_port], database: 'admin',
                                   user: admin_user[:user], password: Base64.decode64(admin_user[:password]))
        self.ensure_user(client.database, admin_user)

        if databases = @mongodb[:databases]
          databases.each do |database, params|
            print "\n   |+ Fake Run: " if options[:pretend]
            puts "\n  Reviewing database: #{database}"
            db = client.use(database).database
            params[:users].each do |user|
              puts "  > Checking user: #{user[:user]}"
              self.ensure_user(db, user)
            end
          end
        end
      end

      private
      def self.load_mongodb_conf
        updated_conf = false
        @mongodb[:mongodb_conf] = @mongodb[:mongodb_conf] ?
                                    @mongodb[:mongodb_conf] :
                                    '/etc/mongodb.conf'
        mongodb_conf = File.exist?(@mongodb[:mongodb_conf]) ? YAML.load_file(@mongodb[:mongodb_conf]) : Hash.new

        generated_mongodb_conf = self.generate_mongodb_conf
        updated_conf = mongodb_conf != generated_mongodb_conf
        [generated_mongodb_conf, updated_conf]
      end

      def self.generate_mongodb_conf
        if File.readlines('/etc/security/limits.conf').grep(/mongodb/).empty?
          entry =  'mongodb         soft     nofile          32000'
          entry += 'mongodb         hard     nofile          64000'
          File.open('/etc/security/limits.conf', 'a+') do |f|
            f.write entry
          end
        end

        mongodb_conf = {
          'net'       => { 'port'    => 27017, 'bindIp' => '127.0.0.1' },
          'storage'   => { 'dbPath' => '/var/lib/mongodb' },
          'systemLog' => { 'destination' => 'file',
                           'path'        => '/var/log/mongodb/mongodb.log',
                           'quiet'       => true,
                           'logAppend'   => true }
        }

        if @mongodb[:config]
          mdb_conf = DanarchyDeploy::Helpers.hash_symbols_to_strings(@mongodb[:config])
          mongodb_conf = mongodb_conf.deep_merge(mdb_conf)
        end

        mongodb_conf
      end

      def self.save_mongodb_conf(mongodb_conf)
        if @options[:pretend]
          puts "\n   |+ Fake run: Saving MongoDB Configuration"
        else
          puts 'Saving MongoDB Configuration'
          File.write(@mongodb[:mongodb_conf], mongodb_conf.to_yaml)
        end
      end

      # def self.ensure_admin_user(host_port, admin_user)
      #   begin
      #     client = Mongo::Client.new([host_port], database: 'admin',
      #                                username: admin_user[:user], password: admin_user[:password])
      #     database = client.database
      #     database.users.info(admin_user[:user])
      #   rescue Mongo::Auth::Unauthorized, Mongo::Error => e
      #     puts e.message

      #     if @options[:pretend]
      #       puts "   |+ Fake Run:   Creating admin user #{admin_user[:user]}"
      #     else
      #       client = Mongo::Client.new([host_port], database: 'admin')
      #       db = client.database
      #       self.ensure_user(db, admin_user)
      #     end
      #   end
      # end

      def self.generate_admin_user
        password = @mongodb[:admin_password] ?
                     @mongodb[:admin_password].chomp :
                     Base64.encode64(SecureRandom.base64(14)).chomp
        
        { user:     "admin",
          password: password,
          roles: [{ role: "root", db: "admin" },
                  { role: "userAdminAnyDatabase", db: "admin" },
                  { role: "dbAdminAnyDatabase",   db: "admin" },
                  { role: "readWriteAnyDatabase", db: "admin" }] }
      end

      def self.load_admin_user
        admin_user = nil
        new_user   = false

        if File.exist?('/root/.mdb_admin_user.json')
          admin_user = JSON.parse(File.read('/root/.mdb_admin_user.json'), symbolize_names: true)
        else
          admin_user = self.generate_admin_user
          self.save_admin_user(admin_user) if ! @options[:pretend]
          new_user = true
        end

        [admin_user, new_user]
      end

      def self.save_admin_user(admin_user)
        File.write('/root/.mdb_admin_user.json', JSON.pretty_generate(admin_user))
      end

      def self.ensure_user(db, user)
        puts user if @options[:vars_verbose]
        password = Base64.decode64(user[:password]).chomp
        if @options[:pretend]
          puts "\n    |+ Fake Run: Creating/Updating user: #{user[:user]}"
        elsif db.users.info(user[:user]).empty?
          puts "\n    |+ Creating user: #{user[:user]}"
          db.users.create(user[:user], password: password, roles: user[:roles])
        else
          puts "\n    |+ Updating user: #{user[:user]}"
          db.users.update(user[:user], password: password, roles: user[:roles])
        end
      end
    end
  end
end
