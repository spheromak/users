# Chaman:
# Monkey patch for the issue on unlocking a passwordless user
# See http://tickets.opscode.com/browse/CHEF-3352

require 'chef/provider/user'

class Chef
  class Provider
    class User
      # Useradd monkey patch
      class Useradd < Chef::Provider::User
        def unlock_user
          cmd = ('rhat' == node[:platform_family]) ? 'passwd -u' : 'usermod -U'
          run_command(command: "#{cmd} #{@new_resource.username}")
        end
      end
    end
  end
end
