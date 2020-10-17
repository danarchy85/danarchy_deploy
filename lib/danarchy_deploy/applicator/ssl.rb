
module DanarchyDeploy
  module Applicator
    module SSL
      class SelfSigned

      end

      class LetsEncrypt
        # DateTime.now > DateTime.parse(cert.grep(/Not After/).first.split(' : ').last) - 7
      end
    end
  end
end
