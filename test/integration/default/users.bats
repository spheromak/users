# vim: set ft=sh:

@test "check dbag users setup"  {
  [ -d /home/yoda ]
}

@test "make sure user works" {
  su - yoda -c env
}

@test "user should have .ssh" {
  [ -d /home/yoda/.ssh ]
}

@test "user should have keyfile" {
  [ -f /home/yoda/.ssh/authorized_keys ]
}

@test "user should have a key" {
  grep -q ssh-dss  /home/yoda/.ssh/authorized_keys
}

@test "wheel should be in sudoers" {
  grep -q '%wheel' /etc/sudoers
}

@test "vim should have been installed by user dep" {
  which vim
}

@test "git should have been installed by user dep" {
  which git
}

