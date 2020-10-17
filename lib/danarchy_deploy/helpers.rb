require 'base64'
require 'open3'

module DanarchyDeploy
  class Helpers
    def self.run_command(command, options)
      pid, stdout, stderr = nil
      printf("%14s %0s\n", 'Running:', "#{command}")

      if options[:pretend] && !options[:dev_gem]
        pretend_run(command)
      else
        Open3.popen3(command) do |i, o, e, t|
          pid    = t.pid
          (out, err) = o.read, e.read
          stdout = !out.empty? ? out : nil
          stderr = !err.empty? ? err : nil
        end

        puts "------\nErrored at: #{caller_locations.first.label} Line: #{caller_locations.first.lineno}\nSTDERR: ", stderr, '------' if stderr
        puts "------\nSTDOUT: ", stdout, '------' if stdout && options[:ssh_verbose]
      end
      
      { pid: pid, stdout: stdout, stderr: stderr }
    end

    def self.decode_base64(data)
      Base64.decode64(data)
    end

    def self.encode_base64(data)
      Base64.encode64(data)
    end

    private
    def self.pretend_run(command)
      puts "\tFake run: #{command}"
    end

    def self.hash_except(hash, regex)
      hash.dup.delete_if { |k,v| k.to_s =~ /#{regex}/ }
    end

    def self.hash_symbols_to_strings(hash)
      new_hash = Hash.new
      hash.each do |key, val|
        if val.class == Hash
          new_hash[key.to_s] = Hash.new
          val.each do |k, v|
            new_hash[key.to_s][k.to_s] = v
          end
        else
          new_hash[key.to_s] = val
        end
      end

      new_hash
    end
  end
end
