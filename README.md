# LogicMonitor - Puppet Integeration Demo 

This demo was put together to for the [Puppet/LogicMonitor Integration Webinar](http://puppetlabs.com/blog/how-cedexis-enables-devops-puppet-enterprise-and-logicmonitor). 

All of the code used to create the demo video is included in this repository. If you would like to run the code yourself, there are a few things you will need to do to ensure your environment is ready. 

### Step 1: Install the proper tools

- Vagrant ([https://www.vagrantup.com/downloads.html](https://www.vagrantup.com/downloads.html))
- Terraform ([https://www.terraform.io/downloads.html](https://www.terraform.io/downloads.html))
- awscli ([http://aws.amazon.com/cli/](http://aws.amazon.com/cli/))
- FPM ([https://github.com/jordansissel/fpm](https://github.com/jordansissel/fpm))
- make 


### Step 2: Insert your SSL Certificate and Key into init.sh

Open the file at `lm-demo/terraform/init/puppetdb/init.sh` and replace `## INCLUDE YOUR SSL CERTIFICATE` with the contents of your SSL certificate. Additionally, you'll need to replace `## INCLUDE YOUR SSL KEY` with the contents of your SSL key. 

### Step 3: Generate a Digital Ocean API key
Follow the instructions [here](https://www.digitalocean.com/community/tutorials/how-to-use-the-digitalocean-api-v2)

### Step 4: Create a bucket to store the deb package
_In order to best work with the scripts, you should create your bucket in the US West 2 region._

Using `awscli`:

```aws --region us-west-2 s3 mb lm-demo```

### Step 5: Update references to `demo.com` to match your own URL
There are a few domain references in the scripts. Be sure to update those references to reflect your own domains. There are references in the `puppetdb.conf` file and in the `lmdemo.tf` file.


### Step 6: Update the Logicmonitor API credentials
Add your own Logicmonitor API credentials to `logicmonitor-puppet-demo/puppet/modules/logicmonitor/manifests/config.pp`

### Step 7: Start the project 

1. Open a terminal and navigate to the `lm-demo` repository. 
2. Start Vagrant: `vagrant up`
3. Run make: `make` 
