class Chef
  class Tinc
    # A shortcut to a customer
    def search_hosts_ConnectTo(network)
      hosts = []
      search(:node, "recipes:tinc\\:\\:core AND tinc_net:#{network} AND chef_environment:#{@node.chef_environment}").map do |searchnode|
          matchingnode = searchnode[:tinc][:net][network]
          matchingdefault = searchnode[:tinc][:net][:default]
          hosts << matchingnode[:name] or matchingdefault[:name]
       end
       return hosts
     end
  end
end