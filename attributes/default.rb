
# Every box should have admins
groups = ["wheel"]

default[domain][:accounts][:groups] = groups
default[domain][:accounts][:users] = []
default[domain][:accounts][:ignore_users] = []

