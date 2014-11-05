#LogicMonitor-Puppet

LogicMonitor is a Cloud-based, full stack, IT infrastructure monitoring solution that 
allows you to manage your infrastructure monitoring from the Cloud.
LogicMonitor-Puppet is a Puppet module for automating and managing your LogicMonitor 
(SaaS based, full stack, datacenter monitoring) portal via Puppet.

##LogicMonitor's Puppet module overview
LogicMonitor's Puppet module defines 5 classes and 4 custom resource types. For additional documentation visit http://help.logicmonitor.com/integrations/puppet-integration/

Classes:
* logicmonitor: Handles setting credentials needed for interacting with the LogicMonitor API.
* logicmonitor::config: Provides the default credentials to the logicmonitor class.
* logicmonitor::master: Collects the exported lm_host resources and lm_hostgroup resources. Communicates with the LogicMonitor API
* logicmonitor::collector: Handles LogicMonitor collector management for the device. Declares an instance of lm_collector and lm_installer resources.
* logicmonitor::host: Declares an exported lm_host resource.

Resource Types:
* lm_hostgroup: Defines the behavior of the handling of LogicMonitor host groups. Recommend using exported resources.
* lm_host: Defines the handling behavior of LogicMonitor hosts. Used only within logicmonitor::host class.
* lm_collector: Defines the handling behavior of LogicMonitor collectors. Used only with logicmonitor::collector class.
* lm_installer: Defines the handling behavior of LogicMonitor collector installation binaries. Used only within logicmonitor::collector class.

So far, we've implemented the following features:

* Collector Management    
* Host Management
  * Ensurable (present/absent)
  * Managed parameters:
    * Display name
    * Description
    * Collector
    * Alerting Enabled
    * Group membership
      * Creation of groups/paths which do not yet exist
    * Properties  
* Host Group Management
  * Ensurable (present/absent)
  * Managed parameters:
    * Display name
    * Description
    * Collector
    * Alerting Enabled
    * Creation of parent groups/paths which do not yet exist
    * Properties  

Upcoming features:

* User management
  * Add and remove users
  * Assign user roles

## Requirements

** Ruby (1.8.7 or 1.9.3) and Puppet 3.X **

This is a module written for Puppet 3

** Ruby Gems  JSON Gem **

This module interacts with LogicMonitor's API which is JSON based. JSON gem needed to parse responses from the servers

** storeconfigs **

This module uses exported resources extensively. Exported resources require storeconfigs = true.

## Installation

### Using the Module Tool

    $ puppet module install logicmonitor-logicmonitor

### Installing via GitHub

    $ cd /etc/puppet/modules
    $ git clone git://github.com/logicmonitor/logicmonitor-puppet.git
    $ mv logicmonitor-puppet logicmonitor

## Usage

Modify the "manifests/config.pp" file with your LogicMonitor account information

    class logicmonitor::config {
      # LogicMonitor API access credentials
      # your account name is take from the web address of your account, 
      # eg "https://chipmco.logicmonitor.com"
      $account  = 'chimpco'
      $user     = 'bruce.wayne'
      $password = 'nanananananananaBatman!'
    }

### Logicmonitor::Master Node

The LogicMonitor module uses the the "logicmonitor::master" class as trigger
to decide which host in your infrastructure will be used to modify your 
LogicMonitor account via API calls.  This host must be able to communicate via
SSL with your LogicMonitor account.


    node "puppet-master.lax6.chimpco" {
      # the puppet master is where API calls to the LogicMonitor server are sent from
      include logicmonitor::master
      
      # In this example, the master will also have a collector installed.  This is optional - the
      # collector can be installed anywhere.
      # NOTE:  this collector will be identied by the facter derived FQDN, eg
      # "puppet-master.lax6.chimpco" in this case.
      include logicmonitor::collector  

      # Define default properties and some hostgroups
      #
      # Managing the properties on the root host group ("/") will set the properties for the entire 
      # LogicMonitor account.  These properties can be over-written by setting them on a child 
      # group, or on an individual host.
      @@lm_hostgroup { "/":
        properties => {
          "snmp.community"  => "public",
          "tomcat.jmxports" => "9000",
          "mysql.user"      => "monitoring",
          "mysql.pass"      => "MyMysqlPW"
        },
      }

      # create "Development" and "Operations" hostgroups
      @@lm_hostgroup {"/Development":
        description => 'This is the top level puppet managed host group',
      }

      @@lm_hostgroup {"/Operations":}

      # Create US-West host group, as well as a sub-group "production".  
      # The "production" group will have use a different SNMP community
      @@lm_hostgroup {"/US-West":}
      @@lm_hostgroup {"/US-West/production":
        properties => { "snmp.community"=>"secret_community_RO" },
      }

      @@lm_hostgroup {"/US-East":}

      # Your puppet master node should be monitored too of course!  Add it in,
      # place it in two hostgroups, and set host specific custom properties 
      # that you might use for a custom datasource
      class {'logicmonitor::host':
        collector => "puppet-master.lax6.chimpco",
        groups => ["/Operations", "/US-West"],
        properties => {"test.prop" => "test2", "test.port" => 12345 },
      }
    }

### Add all appX.lax6 nodes into monitoring

    node /^app\d+.lax6/ {
      $lm_collector = "puppet-master.lax6.chimpco"
      
      class {'logicmonitor::host':
        collector => $lm_collector,
        groups => ["/US-West/production"],
        properties => {"jmx.pass" => "MonitorMEEEE_pw_", "jmx.port" => 12345 },
      }
    }
      
### Additional collector and East Coast nodes

    # Install a collector on a dedicated machine for monitoring the East Coast
    # data center
    node "collector1.dc7.chimpco" {
      
      # install a collector on this machine.  It is identified
      # by the facter derived fqdn
      include logicmonitor::collector
      
      # and add it into monitoring
      class {'logicmonitor::host':
        collector  => "collector1.dc7.chimpco",
        groups     => ["/US-East","Operations"]
      }
    }

    # All East coast nodes will be monitored by the previously defined collector
    node /^app\d+.dc7/ {
      class {"logicmonitor::host":
        collector => "collector1.dc7.chimpco",
        groups => ["/US-East"],
      }
    }

