# lmhost.rb
#
#
#
#
#
#
# Author: Ethan Culler-Mayeno
#
#
require 'json'
require 'open-uri'

Puppet::Type.type(:lm_host).provide(:lmhost) do
  desc "This provider handles the creation, status, and deletion of hosts in your LogicMonitor account"

  #
  # prefetch lm_host instances. This allows all lm_host resources to use the same https connection
  # 
  def self.prefetch(instances)
    @accounts = []
    @connections = {}
    instances.each do |name, resource|
      @accounts.push(resource[:account])
    end
    unique_accounts = @accounts.uniq
    unique_accounts.each do |account|
      @connections[account] = new_connection(account + ".logicmonitor.com")
    end
  end
  
  def self.new_connection(host)
    @conn_created_at = Time.now()
    @connection = Net::HTTP.new(host, 443)
    @connection.use_ssl = true
    @connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
    return @connection.start()  #return @connection
  end

  def self.get_connection(account)
    return @connections[account]
  end

  #
  # Functions as required by ensurable types
  #
  def create
    debug("Creating LogicMonitor host \"#{resource[:hostname]}\"")
    #debug(resource[:groups])
    resource[:groups].each do |group|
      if get_group(group).nil?
        debug("Couldn't find parent group #{group}. Creating.")
        recursive_group_create( group, nil, nil, true)
      end
    end
    add_resp = rpc("addHost", build_host_hash(resource[:hostname], resource[:displayname], resource[:collector], resource[:description], resource[:groups], resource[:properties], resource[:alertenable]))
    #debug add_resp
  end

  def destroy
    debug("Removing LogicMonitor host  \"#{resource[:hostname]}\"")
    host = get_host_by_displayname(resource[:displayname]) || get_host_by_hostname(resource[:hostname], resource[:collector])
    if host
      delete_resp = rpc("deleteHost", {"hostId" => host["id"], "deleteFromSystem" => true})
      #debug(delete_resp)
    end
  end

  def exists?
    debug("Checking LogicMonitor for host #{resource[:hostname]}")
    retval = get_host_by_displayname(resource[:displayname]) || get_host_by_hostname(resource[:hostname], resource[:collector])
    retval
  end

  #
  # Display name get and set functions
  #
  def displayname
    debug("Checking displayname on #{resource[:hostname]}")
    disp_name = ""
    host = get_host_by_displayname(resource[:displayname]) || get_host_by_hostname(resource[:hostname], resource[:collector])
    if host
      disp_name << host["displayedAs"]
    end
    disp_name
  end
  
  def displayname=(value)
    debug("Updating displayname on #{resource[:hostname]}")
    update_host(resource[:hostname], value, resource[:collector], resource[:description], resource[:groups], resource[:properties], resource[:alertenable])
  end

  #
  # Description get and set functions
  #
  def description
    debug("Checking the long text description on  #{resource[:hostname]}")
    desc = ""
    host = get_host_by_displayname(resource[:displayname]) || get_host_by_hostname(resource[:hostname], resource[:collector])
    if host
      desc << host["description"]
    end
    desc
  end

  def description=(value)
    debug("Updating the long text description on #{resource[:hostname]}")
    update_host(resource[:hostname], resource[:displayname], resource[:collector], value, resource[:groups], resource[:properties], resource[:alertenable])
  end

  #
  # Monitoring collector get and set functions
  #
  def collector
    debug("Checking for existence of a collector on #{resource[:collector]}")
    collector = nil
    host = get_host_by_displayname(resource[:displayname]) || get_host_by_hostname(resource[:hostname], resource[:collector])
    if host
      agent_json = rpc("getAgent", {"id" => host["agentId"]})
      agent_resp = JSON.parse(agent_json)
      if agent_resp["status"] == 200
        collector = agent_resp["data"]["description"]
      else
        debug("Unable to retrieve collector list from server")
      end
    end
    collector
  end

  def collector=(value)
    debug("Setting monitoring collector to #{resource[:collector]}")
    update_host(resource[:hostname], resource[:displayname], value, resource[:description], resource[:groups], resource[:properties], resource[:alertenable])
  end


  #
  # Alert enable get and set functions
  #
  def alertenable
    debug("Checking if alerting is enabled on #{resource[:hostname]}")
    host = get_host_by_displayname(resource[:displayname]) || get_host_by_hostname(resource[:hostname], resource[:collector])
    host["alertEnable"].to_s
  end

  def alertenable=(value)
    debug("Updating alerting for #{resource[:hostname]}")
    update_host(resource[:hostname], resource[:displayname], value, resource[:description], resource[:groups], resource[:properties], resource[:alertenable])    
  end

  #
  # Group membership get and set functions
  #
  def groups
    debug("Checking for group memberships for #{resource[:hostname]}")
    group_list = []
    host = get_host_by_displayname(resource[:displayname]) || get_host_by_hostname(resource[:hostname], resource[:collector])
    if host
      host["fullPathInIds"].each do |path|
        host_group_json = rpc("getHostGroup", {"hostGroupId" => path[-1]})
        #debug(host_group_json)
        host_group_resp = JSON.parse(host_group_json)
        if host_group_resp["data"]
          if host_group_resp["data"]["appliesTo"].eql?("")
            group_list.push("/" + host_group_resp["data"]["fullPath"])
          end
        else
          debug "Unable to retrieve host group information from server"
        end
      end
    end
    #debug(group_list)
    group_list
  end

  def groups=(value)
    debug("Updating the set of group memberships for  #{resource[:hostname]}")
    value.each do |group|
      unless get_group(group)
        recursive_group_create(group, nil, nil, true)
      end
    end
    update_host(resource[:hostname], resource[:displayname], resource[:collector], resource[:description], value, resource[:properties], resource[:alertenable])
  end

#
# Property functions for checking and setting properties on a host
#
def properties
  debug("Verifying properties for #{resource[:hostname]}")
  properties = {}
  host = get_host_by_displayname(resource[:displayname]) || get_host_by_hostname(resource[:hostname], resource[:collector])
  if host
    host_prop_json = rpc("getHostProperties", {"filterSystemProperties" => true, "host" => host["hostName"], "finalResult" => false})
    host_prop_resp = JSON.parse(host_prop_json)
#      debug(host_prop_json)
    if host_prop_resp["data"]
      host_prop_resp["data"].each do |prop_hash|
        propname = prop_hash["name"]
        if prop_hash["value"].include?("****") and resource[:properties].has_key?(propname)
          debug("Found password property. Verifying against LogicMonitor Servers")
          check_prop = rpc("verifyProperties", {"hostId" => host["id"], "propName0" => propname, "propValue0" => resource[:properties][propname]})
          #debug(check_prop)
          match = JSON.parse(check_prop)
          if match["data"]["match"]
            debug("Password appears unchanged")
            propval = resource[:properties][propname]
          else
            debug("Password has been changed.")
            propval = prop_hash["value"]
          end
        else
          propval = prop_hash["value"]
        end
        if not prop_hash["name"].eql?("system.categories") and not prop_hash["name"].eql?("puppet.update.on")
          if (prop_hash["name"].eql?("snmp.version") and resource[:properties]["snmp.version"]) or not prop_hash["name"].eql?("snmp.version")
            properties.store(propname, propval)
          end
        end
      end
    end
  end
  properties
end

def properties=(value)
  debug("Updating properties for #{resource[:hostname]}")
  update_host(resource[:hostname], resource[:displayname], resource[:collector], resource[:description], resource[:groups], value, resource[:alertenable])
end 


  #
  # Utility functions within the provider
  #

  #update a host

  def update_host(hostname, displayname, collector, description, groups, properties, alertenable)
    host = get_host_by_displayname(displayname) || get_host_by_hostname(hostname, collector)
    h = build_host_hash(hostname, displayname, collector, description, groups, properties, alertenable)
    if host
      h.store("id", host["id"])
    end
    update_resp = rpc("updateHost", h)
    #debug(update_resp)
    update_resp
  end

  #return a host object from displayname
  def get_host_by_displayname(displayname)
    host = nil
    host_json = rpc("getHost", {"displayName" => displayname})
    #debug(host_json)
    host_resp = JSON.parse(host_json)
    if host_resp["status"] == 200
      host = host_resp["data"]
#      debug("Found host matching #{displayname}")
    end
    host
  end
  
  #requires hostname and collector
  def get_host_by_hostname(hostname, collector)
    host = nil
    hosts_json = rpc("getHosts", {"hostGroupId" => 1})
    hosts_resp = JSON.parse(hosts_json)
    collector_resp = JSON.parse(rpc("getAgents", {}))
    if hosts_resp["status"] == 200
      hosts_resp["data"]["hosts"].each do |h|
        if h["hostName"].eql?(hostname)
#          debug("Found host with matching hostname: #{resource[:hostname]}")
#          debug("Checking agent match")
          if collector_resp["status"] == 200
            collector_resp["data"].each do |c|
              if c["description"].eql?(collector)
                host = h
              end
            end
          else
            debug("Unable to retrieve collector list from server")
          end
        end
      end
    else
      debug("Unable to retrieve host list from server" )
    end
    host
  end
  # create hash for add host RPC
  def build_host_hash(hostname, displayname, collector, description, groups, properties, alertenable)
    h = {}
    h.store("hostName", hostname)
    h.store("displayedAs", displayname)
    agent = get_agent(collector)
    if agent
      h.store("agentId", agent["id"])
    end
    if description
      h.store("description", description)
    end
    group_ids = ""
    groups.each do |group|
      group_ids << get_group(group)["id"].to_s
      group_ids << ","
    end
    h.store("hostGroupIds", group_ids.chop)
    h.store("alertEnable", alertenable)
    index = 0
    unless properties.nil?
      properties.each_pair do |key, value|
        h.store("propName#{index}", key)
        h.store("propValue#{index}", value)
        index = index + 1
      end
    end
    h.store("propName#{index}", "puppet.update.on") 
    h.store("propValue#{index}", DateTime.now().to_s)
    h
  end

  def get_agent(description)
    agents = JSON.parse(rpc("getAgents", {}))
    ret_agent = nil
    if agents["data"]
      agents["data"].each do |agent|
        if agent["description"].eql?(description)
          ret_agent = agent
        end
      end
    else
      debug("Unable to get list of collectors from the server")
    end
    ret_agent
  end

  #Build the proper hash for the RPC function
  def build_group_param_hash(fullpath, description, properties, alertenable, parent_id)
    path = fullpath.rpartition("/")
    hash = {"name" => path[2]}
    hash.store("parentId", parent_id)
    hash.store("alertEnable", alertenable)
    unless description.nil?
        hash.store("description", description)
    end
    index = 0
    unless properties.nil?
      properties.each_pair do |key, value|
        hash.store("propName#{index}", key)
        hash.store("propValue#{index}", value)
        index = index + 1
      end
    end
    #hash.store("propName#{index}", "puppet.update.on") 
    #hash.store("propValue#{index}", DateTime.now().to_s)
    hash
  end

  # handle creation of all groups needed for the host to exist.
  def recursive_group_create(fullpath, description, properties, alertenable)
    path = fullpath.rpartition("/")
    parent_path = path[0]
#    debug("checking for parent: #{path[2]}")
    parent_id = 1
    if parent_path.nil? or parent_path.empty?
      debug("highest level")
    else
      parent = get_group(parent_path)
      if not parent.nil?
#        debug("parent group exists")
        parent_id = parent["id"]
      else
        parent_ret = recursive_group_create(parent_path, nil, nil, true) #create parent group with basic information.
        unless parent_ret.nil?
          parent_id = parent_ret
        end
      end
    end
    hash = build_group_param_hash(fullpath, description, properties, alertenable, parent_id)
    resp_json = rpc("addHostGroup", hash)
    resp = JSON.parse(resp_json)
    if resp["data"].nil?
      nil
    else
      resp["data"]["id"]
    end
  end

  # return a group object if "fullpath" exists or nil
  def get_group(fullpath)
    returnval = nil 
    group_list = JSON.parse(rpc("getHostGroups", {}))
    if group_list["data"].nil? 
      debug("Unable to retrieve list of host groups from LogicMonitor Account")
    else
      group_list["data"].each do |group|
        if group["fullPath"].eql?(fullpath.sub("/", ""))    #Check to see if group exists          
          returnval = group
        end
      end
    end
    returnval
  end

  # Simplifies the calling of LogicMonitor RPCs
  def rpc(action, args={})
    company = resource[:account]
    username = resource[:user]
    password = resource[:password]
    url = "https://#{company}.logicmonitor.com/santaba/rpc/#{action}?"
    first_arg = true
    args.each_pair do |key, value|
      url << "#{key}=#{value}&"
    end
    url << "c=#{company}&u=#{username}&p=#{password}"
    #debug(url)
    uri = URI( URI.encode url)
    begin
      http = self.class.get_connection(company)
      req = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(req)
      return response.body
    rescue SocketError => se
      alert "There was an issue communicating with #{url}. Please make sure everything is correct and try again."
    rescue Exception => e
      alert "There was an unexpected issue."
      alert e.message
      alert e.backtrace
    end
    return nil
  end

end
