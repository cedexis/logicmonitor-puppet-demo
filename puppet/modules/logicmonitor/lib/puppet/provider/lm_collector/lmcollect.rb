# lmcollector.rb
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


Puppet::Type.type(:lm_collector).provide(:lmcollect) do
  desc "This provider handles the creation, status, and deletion of collector objects"
  
  def create
    debug("trying to create a new collector")
    create_response = rpc("addAgent", {"autogen" => "true", "description" => resource[:description]})
    debug(create_response)    
  end

  def destroy
    debug("trying to destroy collector")
    description = resource[:description]
    agentlist_json = JSON.parse(rpc("getAgents", {}))
    if agentlist_json["status"] == 200 and not agentlist_json["data"].nil?
      agentlist_json["data"].each do |agent|
        if agent["description"].eql?(resource[:description])
          destroy_response = rpc("deleteAgent", {"id" => agent["id"]})
          debug(destroy_response)
        end
      end
    else
      debug("Was unable to retrive list of existing LogicMonitor collectors")
    end
  end

  def exists?
    returnval = false #only if we find a matching agent change this to true
    #Get the list of collectors according to LogicMonitor
    pre_list = rpc("getAgents", {})
    agent_list_ret = JSON.parse(pre_list)
    if agent_list_ret["status"] == 200
      agent_list = agent_list_ret["data"]
      agent_list_ret["data"].each do |agent|
        if resource[:description].eql?(agent["description"])
          debug("collector found with matching description")
          returnval = true
        end
      end
    else
      debug("the list of collectors could not be retrieved")
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
    uri = URI( URI.encode url )
    begin
      http = Net::HTTP.new(uri.host, 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
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
