
default: build deploy

build:
	vagrant ssh -c "cd /vagrant && make package"
	# update the object in S3
	aws --region us-west-2 s3 mv lm-demo*.deb s3://lm-demo/lm-demo.deb --acl public-read

package:
	# create a deb package for our puppet content
	@mkdir -p deb/etc
	@cp -R puppet deb/etc
	@fpm -s dir -t deb -n lm-demo -C deb .
	# clean up
	@rm -rf deb

deploy:
	@cd terraform && terraform apply && terraform show

destroy:
	cd terraform && terraform destroy
	aws --region us-west-2 s3 rm s3://lm-demo/lm-demo.deb
