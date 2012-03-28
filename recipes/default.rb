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


node[:tinc][:net].each do |network, conf|
	directory "/etc/tinc/#{network}/hosts" do
		owner "root"
		group "root"
		mode "0644"
		recursive true
	end

	template "/etc/tinc/#{network}/tinc.conf" do
		source "tinc.conf"
		mode "0644"
		owner "root"
		group "root"
		variable(
			:hosts_ConnectTo => conf[:hosts_ConnectTo]
			:device => conf[:device]
			:interface => conf[:interface]
			:bind_to => conf[:bind_to]
			:mode => conf[:mode]
			:name => conf[:name]
		)
		notifies(:reload, "service[tinc]")
	end

	ruby_block "generate_key" do
		block do
			require 'openssl'
			rsa_key = OpenSSL::PKey::RSA.new(2048)
			public_key = rsa_key.public_key
			File.open("/etc/tinc/#{network}/rsa_key.priv", 'w') {|f| f.write(rsa_key) }
			conf[:public_key] = public_key
			node.save
		end
		# TODO generate with specif BITS
		notifies :create, "ruby_block[generate_key_run_flag]", :immediately
		notifies(:reload, "service[tinc]")
		not_if { node.attribute?("generate_key_complete") }
	end

	ruby_block "generate_key_run_flag" do
		block do
			node.set['generate_key_complete'] = true
			node.save
		end
		action :nothing
	end

	search(:node, "tinc:net:#{network}") do |matching_node|
		net = matching_node[:tinc][:net][network]
		template "/etc/tinc/#{network}/hosts/#{net[:name]}" do
			source "host"
			mode "0644"
			owner "root"
			group "root"
			variable(
				:address => node[:address]
				:cipher => node[:cipher]
				:digest => node[:digest]
				:compression => node[:compression]
				:subnets => node[:subnets]
				:public_key => node[:public_key]
			)
		end
	end
end

service "tinc" do
	action :nothing
end
