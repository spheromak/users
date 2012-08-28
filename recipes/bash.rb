
template "/etc/profile.d/cloudware-bash.sh" do 
  owner "root"
  group "root"
  mode  0755
end

cookbook_file "/etc/DIR_COLORS" do 
  owner "root"
  group "root"
  mode  0644
end
# dircolors

