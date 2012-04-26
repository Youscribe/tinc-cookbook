class Chef::Recipe::Tinc

def self.default_conf(node=@node)
  return node[:tinc][:net][:default]
end

def self.conf(network, workingnode=@node)
  return workingnode[:tinc][:net][network]
end

def self.search_hosts_ConnectTo(network)
  hosts = []
    Chef::Search::Query.new.search(:node, "recipes:tinc\\:\\:core AND tinc_net:#{network}") do |searchnode| # AND chef_environment:#{@node.chef_environment}
    hosts << conf(network,searchnode)[:name] or default_conf(searchnode)[:name]
  end
  return hosts
end

def self.value(key,network,workingnode=@node)
  Chef::Log.debug("#{key} in network #{network} for node #{workingnode}")
  if key == :subnets
    self.conf(network,workingnode).has_key?(key) ? self.conf(network,workingnode)[key] : [ conf(network,workingnode)[:internal_ipaddress] + "/32" ]
  elsif key == :hosts_ConnectTo
    self.conf(network,workingnode).has_key?(key) ? self.conf(network,workingnode)[key] : self.search_hosts_ConnectTo(network)
  else
    self.conf(network,workingnode).has_key?(key) ? self.conf(network,workingnode)[key] : self.default_conf(workingnode).has_key?(key) ? self.default_conf(workingnode)[key] : self.default_conf(@node)[key]
  end
end

end
