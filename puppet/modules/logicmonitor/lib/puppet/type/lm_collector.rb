# === Define: collector
#
# Manage your LogicMontior collectors. (Server side)
# This resource type allows the collector provider to create a collector in your LogicMonitor account. The created collector is associated with the current device by way of the fqdn
# Sets the server side information required for the creation of an installer binary.
#
# === Parameters
#
# [*namevar*]
#   Or "description"
#   Sets the description of the collector in your LogicMonitor Account.
#   Must be unique, and preferred usage is the node's fully-qualified domain name.
#
# [*osfam*]
#   Set the family of the current device. Currently supported families are Debian, Redhat, and Amazon kernels
#   Support for Windows, and other *nix systems coming soon.
#
# [*account*]
#   LogicMonitor account. Required for API access.
#
# [*user*]
#   LogicMonitor user name. Required for API access.
#
# [*password*]
#   LogicMonitor password. Required for API access.
#
#
# === Examples
#
# Implict use (preferred)
# node{"foobar":
#   include logicmonitor::collector
# }
#
# === Authors
# 
# Ethan Culler-Mayeno <ethan.culler-mayeno@logicmonitor.com>
#
# === Copyright
#
# Copyright 2012 LogicMonitor, Inc
#
#

Puppet::Type.newtype(:lm_collector) do
  @doc = "allows more graceful management of LogicMonitor collectors"
 
  ensurable
  
  newparam(:description, :namevar => true) do
    desc "This is the name property. This is the collector description. Should be unique and tied to the host"
  end

  newparam(:osfam) do
    desc "The operating system of the system to run a collector. Supported Distros: Debian, Redhat, and Amazon. Coming soon: Windows "
    valid_list = ["redhat", "debian", "amazon"]
    validate do |value|
      unless valid_list.include?(value.downcase())
        raise ArgumentError, "%s is not a valid distribution for a collector. Please install on a Debian, Redhat, or Amazon operating system" % value
      end
    end
  end

  newparam(:account) do
    desc "This is the LogicMonitor account name"
  end

  newparam(:user) do
    desc "this is the LogicMonitor Username"
  end

  newparam(:password) do
    desc "this is the password to make API calls and the LogicMonitor User provided"
  end

end
