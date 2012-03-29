if node[:platform_version].to_f >= 9.10
	cookbook_file "/etc/init/tinc.conf" do
		source "upstart-tinc.conf"
		owner "root"
		group "root"
		mode "0644"
	end

	cookbook_file "/etc/init/tinc-all.conf" do
		source "upstart-tinc-all.conf"
		owner "root"
		group "root"
		mode "0644"
	end

	service "tinc-all" do
		provider Chef::Provider::Service::Upstart
	end
end
