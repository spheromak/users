# system login defs 
cookbook_file "/etc/login.defs" do
  mode "0644"
  owner "root"
  group "root"
end
