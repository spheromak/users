#
# Cookbook Name:: users
# Recipe:: default
#
# Jesse Nelson <spheromak@gmail.com>
# Jason K. Jackson <jasonjackson@gmail.com>

include_recipe  'users::bash'
include_recipe  'users::login'

# Setup Users lib
KTC::User.node = node
KTC::User.run_context = run_context

# Remove users
search(:users, 'status:remove') do |user|
  KTC::User.remove_user user
end

# Remove groups
search(:groups, 'status:remove') do |group|
  KTC::User.remove_group group
end

#
# create all groups first then loop through and add users
# This way a user can be in many groups
#
node[:accounts][:groups].each do |group|
  KTC::User.setup_group(group)
end

node[:accounts][:groups].each do |group|
  members = KTC::User.group_members group

  unless members.empty?
    members.each do |user|
      next if node[:accounts][:ignore_users].include?(user)
      KTC::User.setup_user user
      KTC::User.setup_env  user
    end
  end
  KTC::User.setup_group(group, members)
end

node[:accounts][:users].each do |user|
  next if node[:accounts][:ignore_users].include?(user)
  KTC::User.setup_user user
  KTC::User.setup_env  user
end
