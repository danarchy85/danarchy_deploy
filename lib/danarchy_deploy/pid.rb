module DanarchyDeploy
  class Pid
    attr_reader :pid
    attr_reader :locked
    attr_reader :message

    def initialize
      @pidfile = '/var/run/danarchy_deploy.pid'
      @pid = File.exist?(@pidfile) ? File.read(@pidfile).chomp.to_i : nil
      @locked = false

      if @pid
        begin
          Process.getpgid(@pid)
          @locked = true
          @message = "dAnarchy Deploy is already running as PID: #{@pid}"
        rescue Errno::ESRCH => e
          @locked = false
          @message = "dAnarchy Deploy is not currently running."
        end
      end

      if @locked == false
        @pid = Process.pid
        @locked = false
        @message = "dAnarchy Deploy has started as PID: #{@pid}"
        File.write(@pidfile, @pid)
      end
    end

    def cleanup
      File.delete(@pidfile)
      @pid = nil
      @locked = false
      @message = "dAnarchy Deploy has completed. Cleaning up PID"
    end
  end
end  
