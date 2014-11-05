# lminstall.rb
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

Puppet::Type.type(:lm_installer).provide(:lminstall) do
  desc "This provider handles interacting with your LogicMonitor account to download and install a collector"
  
  def create
    debug("Downloading new collector installer")
    agent_list = JSON.parse(rpc("getAgents", {}))
    if agent_list["status"] == 200 and not agent_list["data"].nil?
      agent_list["data"].each do |agent|
        if resource[:description].eql?(agent["description"])
          id = agent["id"]
          if resource[:architecture].include?("64")
            installfile = resource[:install_dir] + "logicmonitorsetup" + id.to_s + "_64.bin"
            arch = 64
          else
            installfile = resource[:install_dir] + "logicmonitorsetup" + id.to_s + "_32.bin"
            arch = 32
          end
          File.open(installfile, "w+"){ |f|
            f.write(download("logicmonitorsetup", {"id" => id.to_s, "arch" => arch.to_s,}))
          }
          debug("Installing LogicMonitor collector")
          File.chmod(0755, installfile) 
          execution = `#{installfile} -y`
          debug(execution.to_s)
        end
      end
    else
      debug("Unable to retrive list of LogicMonitor collectors")
    end
  end

  def destroy
    debug("Uninstalling LogicMonitor collector")
        agent_list = JSON.parse(rpc("getAgents", {}))
    if agent_list["status"] == 200 and not agent_list["data"].nil?
      agent_list["data"].each do |agent|
        if resource[:description].eql?(agent["description"])
          id = agent["id"]
          uninstaller = resource[:install_dir] + "agent/bin/uninstall.pl"
          execution = `#{uninstaller}`
          debug(execution)
          if resource[:architecture].include?("64")
            installfile = resource[:install_dir] + "logicmonitorsetup" + id.to_s + "_64.bin"
          else
            installfile = resource[:install_dir] + "logicmonitorsetup" + id.to_s + "_32.bin"
          end
          debug("Removing installer from system")
          `rm -f #{installfile}`
        end
      end
    else
      debug("Unable to retrive list of LogicMonitor collectors")
    end

  end

  def exists?
    returnval = false
    agent_list = JSON.parse(rpc("getAgents", {}))
    if agent_list["status"] == 200 and not agent_list["data"].nil?
      agent_list["data"].each do |agent|
        if resource[:description].eql?(agent["description"])
          id = agent["id"]
          if resource[:architecture].include?("64")
            installfile = resource[:install_dir] + "logicmonitorsetup" + id.to_s + "_64.bin"
          else
            installfile = resource[:install_dir] + "logicmonitorsetup" + id.to_s + "_32.bin"
          end
          debug("Checking for install file: #{installfile}")
          returnval = File.exists?(installfile)
        end
      end
    else
      debug("Unable to retrive list of LogicMonitor collectors")
    end
    if returnval
      debug("Installer binary found")
    else
      debug("Installer binary not found")
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
      alert "There was an issue."
      alert e.message
      alert e.backtrace
    end
    return nil
  end

  def download(action, args={})
    company = resource[:account]
    username = resource[:user]
    password = resource[:password]
    url = "https://#{company}.logicmonitor.com/santaba/do/#{action}?"
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
