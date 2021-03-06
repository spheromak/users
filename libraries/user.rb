module  KTC
  # User module
  module User
    class << self
      attr_accessor :node, :run_context

      if Chef::Version.new(Chef::VERSION) <= Chef::Version.new('11.0.0')
        include Chef::Mixin::Language
      else
        include Chef::DSL::DataQuery
      end

      def in_passwd?(user)
        f = File.new('/etc/passwd', 'r')
        text = f.read
        if text =~ /^#{user}:/
          true
        else
          false
        end
      end

      def in_group?(user)
        f = File.new('/etc/group', 'r')
        text = f.read
        if text =~ /^#{user}:/
          true
        else
          false
        end
      end

      # if cached is true and node.run_state[:helper_cache][:all_users] is
      # already set, get_user reads from and write into the cache.
      # rubocop:disable MethodLength
      def get_user(usr = nil, cached = true)
        if usr.is_a? String
          node.run_state[:helper_cache] ||= {}
          if cached &&
            node.run_state[:helper_cache].key?(:all_users) &&
            !node.run_state[:helper_cache][:all_users].nil?

            i = node.run_state[:helper_cache][:all_users].index do |u|
              u['id'] == usr
            end
            if !i.nil?
              usr = node.run_state[:helper_cache][:all_users].fetch(i)
            else
              usr = data_bag_item('users', usr)
              node.run_state[:helper_cache][:all_users] << usr
            end
          else
            usr = data_bag_item('users', usr)
          end
        end
        usr
      end

      def remove_group(g)
        r = Chef::Resource::Group.new  g['id'], run_context
        r.run_action :remove
      end

      def remove_user(u)
        r = Chef::Resource::User.new u['id'], run_context
        r.supports manage_home: node[:users][:manage_home]
        r.run_action :remove
      end

      def setup_user(u)
        u = get_user(u)
        Chef::Log.debug "u: #{u}"
        home = get_home(u)
        status = get_user_status(u)
        if status =~ /remove/
          remove_user(u) unless home.nil?
        else
          # create the dir here if its missing
          d = Chef::Resource::Directory.new home, run_context
          d.owner u['uid']
          d.group 'wheel'
          d.mode 00750
          d.not_if { File.directory? home }
          d.run_action :create

          action = [:create, :manage]
          action << status.to_sym if status =~ /lock/
          r = Chef::Resource::User.new u['id'], run_context
          r.uid      u['uid']
          r.gid      u['groups'].first
          r.shell    get_shell(u)
          r.comment  u['comment']
          r.supports manage_home: node[:users][:manage_home]
          # home is an method in user class
          #       home is the var we set up top
          r.home home
          unless home.nil?
            if action.respond_to? :each
              action.each { |act| r.run_action act }
            else
              r.run_action action
            end
          end
        end
      end

      # if cached is true and node.run_state[:helper_cache][:groups] is already
      # set, it searches the cache.  It doesn't store groups in the cache. only
      # group_members put groups into the cache.
      # rubocop:disable CyclomaticComplexity, AssignmentInCondition, LineLength
      def get_group(grp, cached = true)
        if grp.is_a? String
          node.run_state[:helper_cache] ||= {}
          # TODO: the folowing if ugly as fuck but logically correct.
          # for the love of god and all that is holy FIXME!!!!!
          if cached &&
            node.run_state[:helper_cache].key?(:groups) &&
            !node.run_state[:helper_cache][:groups].nil? &&
            i = node.run_state[:helper_cache][:groups].index { |g| g['id'] == grp }

            group = node.run_state[:helper_cache][:groups].fetch(i)
          else
            begin
              group = data_bag_item('groups', grp)
            rescue Net::HTTPServerException => e
              Chef::Log.error "Error pulling group databag: #{grp}"
              Chef::Log.error "Probably doesn't exist: #{e.message}"
              group = nil
            end
          end
        end
        group
      end

      def setup_group(grp, users = nil)
        grp = get_group(grp)
        if grp
          r = Chef::Resource::Group.new grp['id'], run_context
          if users
            r.members users
            r.append grp['append'] if grp.key? 'append'
          else
            r.append true
          end
          r.gid grp['gid']
          r.run_action :create
        end
      end

      # If cached is true, group_members fetches groups and users from data bag
      # into node.run_state[:helper_cache] if they are not yet in the cache.
      # If they are already in the cache, it doesn't try to search them.
      # Node.run_state[:helper_cache][:groups] and
      # node.run_state[:helper_cache][:all_users] are initialized only by
      # group_members.  That is, if you want to use cached users, you must call
      # group_members or all_users first.
      def group_members(grpid, cached = true)
        grpid = grpid['id'] unless grpid.is_a? String
        list = []
        if cached
          node.run_state[:helper_cache] ||= {}
          node.run_state[:helper_cache][:all_users] ||= []
          node.run_state[:helper_cache][:groups] ||= []

          Chef::Log.debug "Using cached group members for #{grpid}"
          # if this is the first time through these things shouldn't be
          # populated
          unless node.run_state[:helper_cache][:groups].empty? ||
            node.run_state[:helper_cache][:all_users].empty?
            node.run_state[:helper_cache][:groups].each do |g|
              if grpid == g['id']
                node.run_state[:helper_cache][:all_users].each do |u|
                  # rubocop:disable BlockNesting
                  list << u['id'] if u['groups'].include?(grpid)
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

      # all_users fetches all user's id list in node[:accounts][:groups] groups
      # and node[:accounts][:users].  It calls group_members for each group so
      # that every group users are stored in node.run_state[:helper_cache]
      # if cached is true.
      def all_users(cached = true)
        users = []
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
        if u.key?('status')
          case u['status']
          when 'remove', 'lock', 'unlock'
            u['status']
          else
            Chef::Log.warn "user[#{u['id']}] status:'#{u['status']}' is not in"
            Chef::Log.warn "'remove/lock/unlock'. Ignoring it."
            nil
          end
        end
      end

      def get_home(u)
        u = get_user(u)
        u['home'] ? u['home'] : "/home/#{u['id']}"
      end

      def get_shell(u)
        u = get_user(u)
        u['shell'] ? u['shell'] : '/bin/false'
      end

      def setup_env(u)
        u = get_user(u)
        return if u['status'] =~ /remove/
        return unless u.key?('setup')

        # rubocop:disable Eval
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
        users = []
        all_users.each do |u|
          Chef::Log.debug("Processing user: #{u}")
          usr = get_user(u)
          next if usr['status'] =~ /remove/
          next unless usr.key?('setup')

          usr['setup'].each do |cmd|
            users << usr['id'] if cmd =~ /#{setup}/
          end
        end
        users
      end

      def user_dotfile(u, rc)
        usr = get_user(u)
        home_dir = get_home(u)

        r = Chef::Resource::Template.new  "#{home_dir}/.#{rc}", run_context
        r.source "#{rc}.erb"
        r.owner  usr['id']
        r.group  usr['groups'].first
        r.mode   '0600'
        r.variables u: usr

        r.run_action :create if home_dir && ::File.exist?(home_dir)
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
end
