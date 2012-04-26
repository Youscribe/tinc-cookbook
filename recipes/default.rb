#
# Cookbook Name:: tinc
# Recipe:: default
#
# Author:: Guilhem Lettron <guilhem.lettron@youscribe.com>
#
# Copyright 20012, Societe Publica.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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

# we don't need to edit nets.boot if we use /etc/network/interfaces
if ! node[:recipes].include?("network_interfaces")
  template "/etc/tinc/nets.boot" do
  	source "nets.boot.erb"
  	owner "root"
  	group "root"
  	mode "0644"
  	variables(
  		:networks => node[:tinc][:net].keys.reject do |key| key == "default" end
  	)
  end
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
			:hosts_ConnectTo => Tinc.value(:hosts_ConnectTo, network, node),
			:device => Tinc.value(:device, network, node),
			:interface => Tinc.value(:interface, network, node),
			:bind_to => Tinc.value(:bind_to, network, node),
			:mode => Tinc.value(:mode, network, node),
			:name => Tinc.value(:name, network, node)
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
			conf[:public_key] = public_key
			node.save
		end
		# TODO generate with specif BITS
#		notifies(:reload, "service[tinc]")
		not_if { conf.has_key?(:public_key) }
	end

	search(:node, "tinc_net:#{network} AND recipes:tinc") do |matching_node|
		net = matching_node[:tinc][:net][network]
		matchingdefault = matching_node[:tinc][:net][:default]
		netname = Tinc.value(:name, network, matching_node)
		template "/etc/tinc/#{network}/hosts/#{netname}" do
			source "host.erb"
			mode "0644"
			owner "root"
			group "root"
			variables(
				:ipaddress => Tinc.value(:name, network, matching_node),
				:cipher => Tinc.value(:name, network, matching_node),
				:digest => Tinc.value(:name, network, matching_node),
				:compression => Tinc.value(:name, network, matching_node),
				:subnets => Tinc.value(:subnets, network, matching_node),
				:public_key => net[:public_key]
			)
		end
	end

	if node[:recipes].include?(:network_interfaces)
	  network_interfaces Tinc.value(:interface, network, matching_node) do
	    target Tinc.value(:internal_ipaddress, network, node)
	    mask Tinc.value(:internal_netmask, network, node)
	    custom "tinc-net"   # { 'tinc-net' => "#{network}" }
	  end
	else
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
  
  	ifconfig Tinc.value(:internal_ipaddress, network, node) do
  		device Tinc.value(:interface, network, node)
  		mask Tinc.value(:internal_netmask, network, node)
  		# old command
  		#command "ifconfig #{net[:interface]} #{net[:internal_ipaddress} #{net[:subnets][0]}"
  		action :nothing
  	end
	end
end



service "tinc-all" do
	supports :restart => true, :reload => true
	action :enable
end
