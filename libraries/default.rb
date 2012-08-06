class Chef::Recipe::Tinc

def self.public(network, node)
#	nodeconf = Chef::Search::Query.new.search('tinc_' + network, "id:" + workingnode.gsub(".","DOT")).first
#	if nodeconf.length != 0
		return Chef::DataBagItem.load('tinc_' + network, node.name.gsub(".","DOT"))
#	else
#		return {}
#	end
end

def self.public_default(network)
#	defaultconf = Chef::Search::Query.new.search('tinc_' + network, 'id:default').first
#	if defaultconf.length != 0
		return Chef::DataBagItem.load('tinc_' + network, 'default')
#	else
#		return {}
#	end
end

def self.search_hosts_ConnectTo(network,node)
  hosts = []
  Chef::Search::Query.new.search(:node, "recipes:tinc\\:\\:core AND tinc_net:#{network}") do |searchnode| # AND chef_environment:#{@node.chef_environment}
    Chef::Log.debug("ConnectTo #{self.public_value('name',network,searchnode, node)}")
    hosts <<  self.public_value('name',network,searchnode,node)
  end
  return hosts
end

def self.conf_value(key,network,node)
  Chef::Log.debug("conf_value : #{key} in network #{network} for node #{node.name}")
  if key == 'hosts_ConnectTo'
    node['tinc']['net'][network].has_key?(key) ? node['tinc']['net'][network][key] : self.search_hosts_ConnectTo(network, node)
  else
    node['tinc']['net'][network].has_key?(key) ? node['tinc']['net'][network][key] : self.public_default(network).has_key?(key) ? self.public_default(network)[key] : node['tinc']['net']['default'][key]
  end
end

def self.public_value(key,network,workingnode,node)
  Chef::Log.debug("Public_value : #{key} in network #{network} for node #{workingnode.name}")
  pubValues = self.public(network,workingnode)
  defPubValues = self.public_default(network)
  if key == 'subnets'
    if pubValues.has_key?(key)
      pubValues[key]
    else
      [ workingnode['tinc']['net'][network]['internal_ipaddress'] + "/32" ]
    end
  elsif key == 'external_ipaddress'
    if pubValues.has_key?(key)
      pubValues[key]
    elsif defPubValues.has_key?(key)
      defPubValues[key]
    else
      workingnode['ipaddress']
    end
  elsif key == 'name'
    if pubValues.has_key?(key)
      pubValues[key]
    elsif defPubValues.has_key?(key) 
      defPubValues[key]
    else
        workingnode['hostname'].gsub("-", "_")
    end
  else
    if pubValues.has_key?(key) 
      return pubValues[key] 
    elsif defPubValues.has_key?(key) 
      defPubValues[key] 
    elsif workingnode['tinc']['net'][network].has_key?(key)
      workingnode['tinc']['net'][network][key]
    else
      node['tinc']['net']['default'][key]
    end
  end
end

def self.attribute_value(key,network,node)
  Chef::Log.debug("attribute_value : #{key} in network #{network} for node #{node.name}")
  if key == 'subnets'
    node['tinc']['net'][network].has_key?(key) ? node['tinc']['net'][network][key] : node['tinc']['net']['default'].has_key?(key) ? node['tinc']['net']['default'][key] : [ node['tinc']['net'][network]['internal_ipaddress'] + "/32" ]
  else
    node['tinc']['net'][network].has_key?(key) ? node['tinc']['net'][network][key] : node['tinc']['net']['default'][key]
  end
end

end
