
provider "digitalocean" {
    token = "<<DIGITAL OCEAN KEY>>"
}

resource "digitalocean_droplet" "puppetdb" {
    image = "ubuntu-14-04-x64"
    name  = "puppetdb.demo.com"
    region = "sfo1"
    size = "1gb"
    count = 1
    ssh_keys = [ <<SSH KEY>> ]

    connection {
        user = "root"
        type = "ssh"
        key_file = "~/.ssh/id_rsa"
        timeout = "2m"
    }

    provisioner "remote-exec" {
        script = "init/puppetdb/init.sh"
    }

}

resource "digitalocean_droplet" "candidate" {
    image = "ubuntu-14-04-x64"
    name = "candidate-${count.index}.demo.com"
    region = "sfo1"
    size = "1gb"
    depends_on = "digitalocean_droplet.puppetdb"
    count = 5
    ssh_keys = [ <<SSH KEY>> ]

    connection {
        user = "root"
        type = "ssh"
        key_file = "~/.ssh/id_rsa"
        timeout = "2m"
    }

    provisioner "remote-exec" {
        inline = [
            "apt-get -y install wget",
            "wget https://apt.puppetlabs.com/puppetlabs-release-precise.deb",
            "dpkg -i puppetlabs-release-precise.deb",
            "apt-get update",
            "apt-get -y upgrade",
            "apt-get -y install puppet puppetdb-terminus",
            "puppet module install logicmonitor-logicmonitor",
            "wget https://s3-us-west-2.amazonaws.com/lm-demo/lm-demo.deb",
            "dpkg --force-overwrite -i lm-demo.deb",
            "echo '${digitalocean_droplet.puppetdb.ipv4_address} puppetdb.example.com' >> /etc/hosts",
            "puppet apply --modulepath /etc/puppet/modules /etc/puppet/manifests/site.pp"
        ]
    }


}
