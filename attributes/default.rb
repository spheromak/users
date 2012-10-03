
# Every box should have admins
groups = ["wheel"]
default[:accounts][:groups] = groups
default[:accounts][:users] = []
default[:accounts][:ignore_users] = []

