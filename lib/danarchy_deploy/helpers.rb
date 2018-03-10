require 'open3'

module DanarchyDeploy
  class Helpers
    def self.run_command(command, options)
      pid, stdout, stderr = nil
      printf("%14s %0s\n", 'Running:', "#{command}")
      Open3.popen3(command) do |i, o, e, t|
        pid    = t.pid
        (out, err) = o.read, e.read
        stdout = !out.empty? ? out : nil
        stderr = !err.empty? ? err : nil
      end

      if options[:ssh_verbose]
        puts "------\nSTDOUT: ", stdout, '------' if stdout
        puts "------\nSTDERR: ", stderr, '------' if stderr
      end
      
      { pid: pid, stdout: stdout, stderr: stderr }
    end

    def self.decode_base64(data)
      require 'base64'
      Base64.decode64(data)
    end
  end
end
