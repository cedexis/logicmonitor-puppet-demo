#!/usr/bin/env bash

apt-get -y install wget nginx

wget https://apt.puppetlabs.com/puppetlabs-release-precise.deb
dpkg -i puppetlabs-release-precise.deb
apt-get update
apt-get -y upgrade


apt-get -y install puppet

IPADDRESS=`facter ipaddress`
echo "$IPADDRESS          $FQDN" >> /etc/hosts

puppet module install puppetlabs/puppetdb

puppet apply -e "class { 'puppetdb': }"
puppet apply -e "package{ 'puppetdb-terminus': }"

cat <<EOF>/etc/puppetdb/conf.d/jetty.ini
[jetty]
host = 0.0.0.0
port = 8080
EOF
/sbin/service puppetdb restart

cat <<EOF>/etc/nginx/nginx.conf
worker_processes  1;
env HOME;

events {
    worker_connections  65536;
    use epoll;
}

http {

## Size Limits
    client_body_buffer_size         2m;
    client_header_buffer_size       2m;
    client_max_body_size            2m;
    large_client_header_buffers 1 2m;

## Timeouts 
    client_body_timeout   5;
    client_header_timeout 5;
    keepalive_requests    0;
    keepalive_timeout     1 1;
    send_timeout          5;
    tcp_nodelay           on;
    tcp_nopush            off;
    include           mime.types;
    default_type             application/octet-stream;
    access_log               off;
    error_log               off;
    server {
        listen 8081 ssl;

        server_name puppetdb.demo.com;

        ssl_certificate              /etc/ssl/certs/demo.cert;
        ssl_certificate_key          /etc/ssl/certs/demo.key;
        ssl_session_timeout  5m;
        ssl_protocols  SSLv2 SSLv3 TLSv1;
        ssl_ciphers  ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP;
        ssl_prefer_server_ciphers   on;
        add_header Access-Control-Allow-Origin *;

        location / {
            proxy_pass http://localhost:8080;
        }
    }
}
EOF

cat<<EOF>/etc/ssl/certs/demo.cert
## INCLUDE YOUR SSL CERTIFICATE
EOF

cat<<EOF>/etc/ssl/certs/demo.key
## INCLUDE YOUR SSL KEY
EOF

service nginx restart

wget https://s3-us-west-2.amazonaws.com/lm-demo/lm-demo.deb
dpkg --force-overwrite -i lm-demo.deb
sleep 60;
puppet apply --modulepath /etc/puppet/modules /etc/puppet/manifests/site.pp
