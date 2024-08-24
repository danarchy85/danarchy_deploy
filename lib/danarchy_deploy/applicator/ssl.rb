
module DanarchyDeploy
  module Applicator
    module SSL
      class SelfSigned

      end

      class LetsEncrypt
        # Time.now > Time.parse(cert.grep(/Not After/).first.split(' : ').last) - 7
      end
    end
  end
end
