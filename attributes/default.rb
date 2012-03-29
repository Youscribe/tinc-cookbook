#default[:tinc][:net] = [ "vpn" ]
#default[:tinc][:net].inspect

default[:tinc][:net][:vpn][:internal_ipaddress] = "192.168.55.12"
default[:tinc][:net][:vpn][:subnets] = [ "192.168.55.0/24" ]

default[:tinc][:net][:default][:device] = "/dev/net/tun"
default[:tinc][:net][:default][:interface] = "tun0"
default[:tinc][:net][:default][:bind_to] = "eth0"
default[:tinc][:net][:default][:mode] = "router"
default[:tinc][:net][:default][:name] = node[:hostname].gsub("-", "_")

default[:tinc][:net][:default][:cipher] = "blowfish"
default[:tinc][:net][:default][:digest] = "sha1"
default[:tinc][:net][:default][:compression] = "0"
