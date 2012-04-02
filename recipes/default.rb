#
# Cookbook Name:: tinc
# Recipe:: default
#
# Copyright 2012, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

package "tinc" do
	action :upgrade
end

# Before lucid, ruby doesn't include openssl
if node[:platform] == "ubuntu" and node[:platform_version].to_f <= 10.04
	package "libopenssl-ruby" do
		action :install
	end
end

if node[:platform] == "ubuntu" and node[:platform_version].to_f >= 9.04
	include_recipe "tinc::upstart"
end	

template "/etc/tinc/nets.boot" do
	source "nets.boot.erb"
	owner "root"
	group "root"
	mode "0644"
	variables(
		:networks => node[:tinc][:net].keys.reject do |key| key == "default" end
	)
end

netdefault = node[:tinc][:net][:default]

node[:tinc][:net].each do |network, conf|
	next if network == "default"


	directory "/etc/tinc/#{network}/hosts" do
		owner "root"
		group "root"
		mode "0644"
		recursive true
	end

	template "/etc/tinc/#{network}/tinc.conf" do
		source "tinc.conf.erb"
		mode "0644"
		owner "root"
		group "root"
		variables(
			:hosts_ConnectTo => conf.has_key?("hosts_ConnectTo") ? conf[:hosts_ConnectTo] : search(:node, "recipes:tinc\\:\\:core AND tinc_net:#{network}").map do |node|
				matchingnode = node[:tinc][:net][network]
				matchingdefault = node[:tinc][:net][:default]
				matchingnode.has_key?("name") ? matchingnode[:name] : matchingdefault[:name]
			 end,
			:device => conf.has_key?("device") ? conf[:device] : netdefault[:device],
			:interface => conf.has_key?("interface") ? conf[:interface] : netdefault[:interface],
			:bind_to => conf.has_key?("bind_to") ? conf[:bind_to] : netdefault[:bind_to],
			:mode => conf.has_key?("mode") ? conf[:mode] : netdefault[:mode],
			:name => conf.has_key?("name") ? conf[:name] : netdefault[:name]
		)
		notifies(:reload, "service[tinc-network-#{network}]")
	end

	# Generate a rsa pub/sec key only 1 time
	ruby_block "generate_key" do
		block do
			require 'openssl'
			rsa_key = OpenSSL::PKey::RSA.new(2048)
			public_key = rsa_key.public_key
			::File.open("/etc/tinc/#{network}/rsa_key.priv","w") do |f| 
				f.chmod(0600)
				f.write(rsa_key) 
			end
			#Chef::Platform::file "/etc/tinc/#{network}/rsa_key.priv" do
			#	owner "root"
			#	group "root"
			#	mode "0600"
			#	content rsa_key
			#end
			conf[:public_key] = public_key
			node.save
		end
		# TODO generate with specif BITS
		notifies(:reload, "service[tinc]")
		not_if { conf.has_key?(:public_key) }
	end

	search(:node, "tinc_net:#{network}") do |matching_node|
		net = matching_node[:tinc][:net][network]
		matchingdefault = matching_node[:tinc][:net][:default]
		netname = net.has_key?("name") ? net[:name] : matchingdefault[:name]
		template "/etc/tinc/#{network}/hosts/#{netname}" do
			source "host.erb"
			mode "0644"
			owner "root"
			group "root"
			variables(
				:ipaddress => net.has_key?("external_ipaddress") ? net[:external_ipaddress] : node[:ipaddress],
				:cipher => net.has_key?("cipher") ? net[:cipher] : matchingdefault[:cipher],
				:digest => net.has_key?("digest") ? net[:digest] : matchingdefault[:digest],
				:compression => net.has_key?("compression") ? net[:compression] : matchingdefault[:compression],
				:subnets => net.has_key?("subnets") ? net[:subnets] : [ net[:internal_ipaddress] + "/32" ]
				:public_key => net[:public_key]
			)
		end
	end

	service "tinc-network-#{network}" do
		pattern "tinc.conf"
		start_command "initctl start tinc NETWORK=\"#{network}\" || initctl status tinc NETWORK=\"#{network}\""
		stop_command "initctl stop tinc NETWORK=\"#{network}\""
		reload_command "initctl reload tinc NETWORK=\"#{network}\""
		restart_command "initctl restart tinc NETWORK=\"#{network}\""
		supports :reload => true, :restart => true
		provider Chef::Provider::Service::Upstart
		notifies(:add, "ifconfig[#{conf[:internal_ipaddress]}]")
		action [:start]
	end

	ifconfig conf[:internal_ipaddress] do
		device conf.has_key?("interface") ? conf[:interface] : netdefault[:interface]
		# old command
		#command "ifconfig #{net[:interface]} #{net[:internal_ipaddress} #{net[:subnets][0]}"
		action :nothing
	end
end



service "tinc" do
	supports :restart => true, :reload => true
	action :enable
end
