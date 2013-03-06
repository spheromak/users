module  Cloud
  module User

    def in_passwd?(user)
      f = File.new("/etc/passwd", "r")
      text = f.read
      if text =~ /^#{user}:/ then
        true
      else
        false
      end
    end

    def in_group?(user)
      f = File.new("/etc/group", "r")
      text = f.read
      if text =~ /^#{user}:/ then
        true
      else
        false
      end
    end
    
    # if cached is true and node.run_state[:helper_cache][:all_users] is already set, 
    # get_user reads from and write into the cache.
    def get_user(usr=nil, cached=true)
      if usr.is_a? String
        node.run_state[:helper_cache] ||= Hash.new
        if cached and node.run_state[:helper_cache].has_key?(:all_users) and node.run_state[:helper_cache][:all_users] != nil
          i = node.run_state[:helper_cache][:all_users].index {|u| u['id'] == usr}
          if i != nil
            usr = node.run_state[:helper_cache][:all_users].fetch(i)
          else
            usr = data_bag_item("users", usr)
            node.run_state[:helper_cache][:all_users] << usr
          end
        else
          usr = data_bag_item("users", usr)
        end
      end
      usr
    end
    
    def remove_user(u)
      user u['id'] do  
        action :remove
        supports :manage_home => true
      end
    end
 
    def setup_user(u)
      u = get_user(u)
      Chef::Log.debug "u: #{u}"
      username = u['id']
      home = get_home(u)
      status = get_user_status(u)
      if status =~ /remove/
        remove_user(u) unless home.nil?
      else
        unless home.nil?
          action = [:create, :manage]
          action << status.to_sym if status =~ /lock/
          user u['id'] do
            uid      u['uid']
            gid      u['groups'].first
            shell    get_shell(u)
            comment  "#{u['comment']}"
            action   action  
            supports :manage_home => true
            # home is an method in user class
            #       home is the var we set up top
            home home
          end
        end
      end
    end

    # if cached is true and node.run_state[:helper_cache][:groups] is already set, it searches the cache.
    # it doesn't store groups in the cache. only group_members put groups into the cache.
    def get_group(grp,cached=true)
      if grp.is_a? String
        node.run_state[:helper_cache] ||= Hash.new
        if cached and node.run_state[:helper_cache].has_key?(:groups) and node.run_state[:helper_cache][:groups] != nil \
          and (i = node.run_state[:helper_cache][:groups].index {|g| g['id'] == grp})
          group = node.run_state[:helper_cache][:groups].fetch(i)
        else
          begin
            group = data_bag_item("groups", grp) 
          rescue Net::HTTPServerException => e
            Chef::Log.error "Error pulling group databag: #{grp}, Probably doesn't exist;#{e.message}"
            group = nil
          end
        end
      end
      group
    end

    def setup_group(grp, users=nil)
      grp = get_group(grp)
      if grp  
        group "#{grp['id']}" do
          if users
            members users
            append grp['append'] if grp.has_key? "append"
          else
            append true
          end
          gid grp['gid']
        end
      end
    end

    # If cached is true, group_members fetches groups and users from data bag
    # into node.run_state[:helper_cache] if they are not yet in the cache.
    # If they are already in the cache, it doesn't try to search them.
    # node.run_state[:helper_cache][:groups] and node.run_state[:helper_cache][:all_users] are initialized only by group_members.
    # That is, if you want to use cached users, you must call group_members or all_users first.
    def group_members(grpid, cached=true)
      grpid = grpid['id'] unless grpid.is_a? String
      list = Array.new
      if cached  
        node.run_state[:helper_cache] ||= Hash.new
        node.run_state[:helper_cache][:all_users] ||= Array.new()
        node.run_state[:helper_cache][:groups] ||= Array.new()

        Chef::Log.debug "Using cached group members for #{grpid} if they exist"
        # if this is the first time through these things shouldn't be populated
        unless node.run_state[:helper_cache][:groups].empty? or node.run_state[:helper_cache][:all_users].empty?
          node.run_state[:helper_cache][:groups].each do |g| 
            if grpid == g['id']
              node.run_state[:helper_cache][:all_users].each do |u|
                # grpid =  id field from group bag i.e. "wheel"
                if u['groups'].include?(grpid)
                  list << u['id']
                end
              end
              return list
            end
          end
          # if grp is not in node.run_state[:helper_cache][:groups]
          node.run_state[:helper_cache][:groups] << get_group(grpid, false)
        end
 
        # if cached is not true or grp members are not in the cache 
        search(:users, "groups:#{grpid} NOT status:remove") do |u|
          list <<  u['id']
          node.run_state[:helper_cache][:all_users] << u if cached 
        end
      end
      Chef::Log.debug "group_members returns list: #{list}."
      list
    end

    # all_users fetches all user's id list in node[:accounts][:groups] groups and
    # node[:accounts][:users].
    # It calls group_members for each group so that every group users are stored in node.run_state[:helper_cache] 
    # if cached is true.
    def all_users(cached=true)
      users = Array.new
      node[:accounts][:groups].each do |group|
        members = group_members(group, cached)
        unless members.empty?
          members.each do |user|
            next if node[:accounts][:ignore_users].include?(user)
            get_user(user, cached) if cached
            users << user
          end
        end
      end

      node[:accounts][:users].each do |u|
        next if node[:accounts][:ignore_users].include?(u)
        get_user(u, cached) if cached
        users <<  u
      end
      Chef::Log.debug "all_users returns list: #{users}."
      users
    end
       
    def get_user_status(u)
      u = get_user(u)
      status = nil
      if u.has_key?('status')
        status = case u['status']
        when "remove", "lock", "unlock" 
          u['status']
        else 
          Chef::Log.warn "user[#{u['id']}] status:'#{u['status']}' is not in 'remove/lock/unlock'. Ignoring it." 
          nil
        end
      end
    end

    def get_home(u)
      u = get_user(u)
      home_dir = u['home'] ? u['home'] : "/home/#{u['id']}"
    end 
    
    def get_shell(u)
      u = get_user(u)
      shell = u['shell'] ? u['shell'] : "/bin/false"
    end
  
    def setup_env(u)
      u = get_user(u)
      return if u['status'] =~ /remove/ 
      return unless u.has_key?('setup')

      u['setup'].each do |cmd|
        Chef::Log.debug("Processing env cmd: #{cmd} for: #{u['id']}")
        if cmd =~ /bash|vim|top|tmux|screen|build/
          eval "setup_#{cmd}(u)"
        else
          Chef::Log.debug("No configuration setup for #{cmd}")
        end
      end 
    end 

    def get_setup_users(all_users, setup)
      users = Array.new
      all_users.each do |u|
        Chef::Log.debug("Processing user: #{u}")
        usr = get_user(u)
        next if usr['status'] =~ /remove/
        next unless usr.has_key?('setup')

        usr['setup'].each do |cmd|
          if cmd =~ /#{setup}/
            users << usr['id']
          end
        end
      end
      users
    end

    def user_dotfile(u, rc)
      usr = get_user(u)
      home_dir = get_home(u)
      if home_dir && ::File.exist?(home_dir)
        template "#{home_dir}/.#{rc}" do
          source "#{rc}.erb"
          owner  usr['id']
          group  usr['groups'].first
          mode   "0600"
          variables :u => usr
        end
      end
    end

    def setup_bash(u)
    end

    def setup_top(u)
    end

    def setup_vim(u)
    end

    def setup_screen(u)
    end

    def setup_tmux(u)
    end

    def setup_build(u)
    end
  end
end
