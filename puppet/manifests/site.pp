
node base {
    include snmpd
    include logicmonitor::collector

    class{"logicmonitor::host":
        collector => $::fqdn,
        groups    => ["/LMDemo"]
    }

    cron{"run-puppet":
        command => "puppet apply --modulepath /etc/puppet/modules /etc/puppet/manifests/site.pp",
        user    => "root",
        minute  => "*"
    }

}

node /^puppetdb/ inherits base {
    ## LogicMonitor Specific
    include logicmonitor::master

    @@lm_hostgroup {"/LMDemo":
        description => "These machines are potential candidates",
        properties => {
            "snmp.community" => "lmd3m0",
            "snmp.version"   => "v2c"
        }
    }
}

node /^candidate/ inherits base {}