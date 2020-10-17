
module DanarchyDeploy
  class Archiver
    class Svn
      def initialize(options)
        @options = options
      end

      def co(repo, path)
        puts "Checking out '#{repo}' to '#{path}'"
        cmd = 'svn --non-interactive --trust-server-cert ' +
              "co #{repo} #{path}"
        DanarchyDeploy::Helpers.run_command(cmd, @options)
      end
    end
  end
end
