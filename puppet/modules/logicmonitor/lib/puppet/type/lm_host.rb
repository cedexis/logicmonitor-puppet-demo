# === Define: host
#
# This resource type defines a host group in your LogicMonitor account.
# The purpose is to introduce the following information into a puppetDB catalog for use by the LogicMonitor Master node.
#
# === Parameters
#
# [*namevar*]
#    Or "hostname" 
#    Sets the path of the group. Path must start with a "/"
#
# [*description*]
#    Set the description shown in the LogicMonitor portal
#
# [*properties*]
#    Must be a Hash object of property names and associated values.
#    Set custom properties at the group level in the LogicMonitor Portal
#
# [*alertenable*]
#    Boolean value setting whether to deliver alerts on hosts within this group.
#    Overrides host level alert enable setting
#
# [*mode*]
#    Set the puppet management mode.
#    purge -
#
# [*opsnote*]
#    Boolean value setting whether to insert an OpsNote into your LogicMonitor account
#    when Puppet changes the host.
#
#
# === Examples
#
#
# === Authors
# 
# Ethan Culler-Mayeno <ethan.culler-mayeno@logicmonitor.com>
#
# === Copyright
#
# Copyright 2012 LogicMonitor, Inc
#

Puppet::Type.newtype(:lm_host) do
  @doc = "Create a new host in LogicMonitor Account "
  ensurable
  
  newparam(:hostname, :namevar => true) do
    desc "The name of the host. Defaults to the fully qualified domain name. Accepts fully qualified domain name or ip address as input."
  end

  newproperty(:displayname) do
    desc "The way the host appears in your LogicMonitor account."
  end

  newproperty(:description) do
    desc "The long text description of a host"
  end

  newproperty(:collector) do
    desc "The description of the collector this host reports to."
    validate do |value|
      unless value.class == String
        raise ArgumentError, "#{value} must be the unique string in the collector \"description\" field"
      end
    end
  end

  newproperty(:alertenable) do
    desc "Set alerting enabled for the host."
    newvalues(:true, :false)
  end
  
  newproperty(:groups, :array_matching => :all) do
        desc "An array where the entries are fullpaths of groups the host should be added to. E.g. [\"/parent/child\", \"/puppet_managed\"]"
    defaultto []
  end
  
  newproperty(:properties) do
    desc "A hash where the keys represent the property names and the values represent the property values. (e.g. {\"snmp.version\" => \"v2c\", \"snmp.community\" => \"public\"})"
    defaultto {}
    validate do |value|
      unless value.class == Hash
        raise ArgumentError, "#{value} is not a valid set of group properties. Properties must be in the format {\"propName0\"=>\"propValue0\",\"propName1\"=>\"propValue1\", ... }"
      end
    end
  end

  newparam(:mode) do
    desc "Set how strict puppet is regarding changes made in the LogicMonitor web application. Valid imputs:\n
\"purge\" - puppet will remove all properties not set by puppet (for groups under puppet control)\n
Additional options coming soon."
    newvalues(:purge)
    defaultto :purge

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
