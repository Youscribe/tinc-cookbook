apt_repository "tinc guilhe-fr ppa" do
	uri "http://ppa.launchpad.net/guilhem-fr/tinc/ubuntu"
	distribution = node[:lsb][:codename]
	components ["main"]
	keyserver "keyserver.ubuntu.com"
	key "97F87FBF"
end

