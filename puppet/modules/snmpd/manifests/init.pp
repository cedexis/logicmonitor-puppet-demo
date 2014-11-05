class snmpd {

    package{'snmpd': ensure => installed}   
    file {'/etc/default/snmpd':
        ensure  => present,
        owner   => root,
        group   => root,
        mode    => 0644,
        require => Package['snmpd']
    }
    file {'/etc/snmp/snmpd.conf':
        ensure  => present,
        owner   => root,
        group   => root,
        mode    => 0644,
        content => template("snmpd/snmpd.conf.erb")
    }

    service {'snmpd':
        enable    => 'true',
        ensure    => 'running',
        hasstatus => 'false',
        require   => [File['/etc/default/snmpd'], File['/etc/snmp/snmpd.conf']],
        subscribe => [File['/etc/default/snmpd'], File['/etc/snmp/snmpd.conf']]
    }
}