# lmhostgroup.rb
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

Puppet::Type.type(:lm_hostgroup).provide(:lmhostgroup) do
  desc "This provider handles the creation, status, and deletion of collector objects"
  
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
    debug("Creating LogicMonitor host group \"#{resource[:fullpath]}\"")
    recursive_create(resource[:fullpath], resource[:description], resource[:properties], resource[:alertenable])
  end

  def destroy
    debug("Removing LogicMonitor host group \"#{resource[:fullpath]}\"")
    host_group = get_group(resource[:fullpath])
    unless host_group.nil?
      ret = rpc("deleteHostGroup", {"hgId" => host_group["id"], "deleteHosts" => false})
    end  
  end

  def exists?
    debug("Checking for hostgroup #{resource[:fullpath]}")
    if resource[:fullpath].eql?("/")
      true
    else
      get_group(resource[:fullpath])
    end
  end

  #
  # Description get and set functions
  #

  def description
    debug("Verifying description for #{resource[:fullpath]}")
    remote_group = get_group(resource[:fullpath])
    remote_group["description"]
  end

  def description=(value)
    debug("Updating description for #{resource[:fullpath]}")
    group = get_group(resource[:fullpath])
    hash = build_param_hash(resource[:fullpath], resource[:description], resource[:properties], resource[:alertenable], group["parentId"])
    hash.store("id", group["id"])
    response = rpc("updateHostGroup", hash)
 #   debug(response)
  end

  #
  # Alert enable get and set functions
  #

  def alertenable
    debug("Verifying alerting status for #{resource[:fullpath]}")
    remote_group = get_group(resource[:fullpath])
    remote_group["alertEnable"].to_s
  end

  def alertenable=(value)
    debug("Updating alerting status for #{resource[:fullpath]}")
    group = get_group(resource[:fullpath])
    hash = build_param_hash(resource[:fullpath], resource[:description], resource[:properties], resource[:alertenable], group["parentId"])
    hash.store("id", group["id"])
    response = rpc("updateHostGroup", hash)
#    debug(response)
  end

  #
  # Property functions for checking and setting properties on a host group
  #
  def properties
    debug("Verifying properties for #{resource[:fullpath]}")
    remote_group = get_group(resource[:fullpath])
    if remote_group.nil?
      debug("Unable to retrive host group information from LogicMonitor")
    else
      remote_details = rpc("getHostGroup", {"hostGroupId" => remote_group["id"], "onlyOwnProperties" => true})
      #debug(remote_details)
      remote_props = JSON.parse(remote_details)
      p = {}
      if remote_props["data"]["properties"]
        remote_props["data"]["properties"].each do |prop|
          propname = prop["name"]
          if prop["value"].include?("****") and resource[:properties].has_key?(propname)
            debug("Found password property. Verifying against LogicMonitor Servers")
            check_prop = rpc("verifyProperties", {"hostGroupId" => remote_group["id"], "propName0" => propname, "propValue0" => resource[:properties][propname]})
            #debug(check_prop)
            match = JSON.parse(check_prop)
            if match["data"]["match"]
              debug("Password appears unchanged")
              propval = resource[:properties][propname]
            else
              debug("Password has been changed.")
              propval = prop["value"]
            end
          else
            propval = prop["value"]
          end
          unless propname.eql?("puppet.update.on")
            p.store(propname, propval)
          end
        end
      end
      p
    end
  end

  def properties=(value)
    debug("Setting properties for host group \"#{resource[:fullpath]}\"")
    group = get_group(resource[:fullpath])
    hash = build_param_hash(resource[:fullpath], resource[:description], resource[:properties], resource[:alertenable], group["parentId"])
    hash.store("id", group["id"])
    response = rpc("updateHostGroup", hash)
    #debug(response)
  end

  #
  # Utility functions within the provider
  #

  def build_param_hash(fullpath, description, properties, alertenable, parent_id)
    if fullpath.eql?("/")
      hash = {"id" => 1 }
    else
      path = fullpath.rpartition("/")
      hash = {"name" => path[2] }
    end
    if parent_id
      hash.store("parentId", parent_id)
    end
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
      #debug(index)
      hash.store("propName#{index}", "puppet.update.on") 
      hash.store("propValue#{index}", DateTime.now().to_s )
      #p hash
      hash
  end

  def recursive_create(fullpath, description, properties, alertenable)
    path = fullpath.rpartition("/")
    parent_path = path[0]
    debug("checking for parent: #{path[2]}")
    parent_id = 1
    if parent_path.nil? or parent_path.empty?
      debug("highest level")
    else
      parent = get_group(parent_path)
      if not parent.nil?
        debug("parent group exists")
        parent_id = parent["id"]
      else
        parent_ret = recursive_create(parent_path, nil, nil, true) #create parent group with basic information.
        unless parent_ret.nil?
          parent_id = parent_ret
        end
      end
    end
    hash = build_param_hash(fullpath, description, properties, alertenable, parent_id)
    resp_json = rpc("addHostGroup", hash)
    resp = JSON.parse(resp_json)
    if resp["data"].nil?
      nil
    else
      resp["data"]["id"]
    end
  end

  def get_group(fullpath)
    returnval = nil 
    if fullpath.eql?("/")
      group = JSON.parse(rpc("getHostGroup", {"hostGroupId" => 1}))
      if group["data"]
        returnval = group["data"]
      end
    else
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
    end
    returnval
  end

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
    uri = URI( URI.encode url )
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
