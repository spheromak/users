
# Every box should have admins
groups = %w/
  wheel
  users
/
default[:accounts][:groups] = groups
default[:accounts][:users] = []
default[:accounts][:ignore_users] = []
# don't do this (try to move home dirs around) by default
default[:users][:manage_home] = false
