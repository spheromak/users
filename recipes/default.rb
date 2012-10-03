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

include_recipe  "vim::cloudware"
include_recipe  "users::bash"
include_recipe  "users::login"

%w/wheel users/.each { |group|  setup_group(group) } 

# Remove users 
search(:users, "status:remove") do |user|
  remove_user user
end

# Remove groups
search(:groups, "status:remove") do |group|
  remove_group group
end


node[:accounts][:groups].each do |group|
  members = group_members group

  # need to make sure the group exists b4 we add users. 
  setup_group(group)

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
