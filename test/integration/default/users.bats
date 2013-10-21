# vim: set ft=sh:

@test "check dbag users setup"  {
  [ -d /home/yoda ]
}

@test "make sure user works" {
  su - yoda -c env
}
