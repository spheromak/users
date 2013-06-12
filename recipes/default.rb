#
# Cookbook Name:: users
# Recipe:: default
#
# Jason K. Jackson <jasonjackson@gmail.com>
# Jesse Nelson <spheromak@gmail.com>

class Chef::Recipe
  include Cloud::User
end

class Chef::Resource::User
  include Cloud::User
end

include_recipe  "ktc-vim"
include_recipe  "users::bash"
include_recipe  "users::login"


# Remove users
search(:users, "status:remove") do |user|
  remove_user user
end

# Remove groups
search(:groups, "status:remove") do |group|
  remove_group group
end

#
# create all groups first then loop through and add users
# This way a user can be in many groups
#
node[:accounts][:groups].each do |group|
  setup_group(group)
end

node[:accounts][:groups].each do |group|
  members = group_members group

  unless members.empty?
    members.each do |user|
      next if node[:accounts][:ignore_users].include?(user)
      setup_user user
      setup_env  user
    end
  end
  setup_group(group, members)
end

node[:accounts][:users].each do |user|
  next if node[:accounts][:ignore_users].include?(user)
  setup_user user
  setup_env  user
end
