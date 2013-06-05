
# Every box should have admins
groups = ["wheel", "users"]
default[:accounts][:groups] = groups
default[:accounts][:users] = []
default[:accounts][:ignore_users] = []

