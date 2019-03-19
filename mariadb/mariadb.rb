#!/usr/bin/env ruby

require_relative '../lib/awslab'

def instance_tags(role, fqdn)
  {
    'Project' => 't-co-mariadb',
    'os' => 'Linux',
    'Role' => role,
    'FQDN' => fqdn,
    'Name' => fqdn.split('.').first
  }
end

def set_hostname(fqdn)
  "hostnamectl set-hostname #{fqdn}"
end

def extra_pkgs
  %(
yum install -y epel-release
yum install -y htop jq

)
end

# isntance types
#   m5a.large   2/ 8/0.10   vcpu/G ram/per hour usage us-west-2
#   m5a.xlarge  4/16/0.20
#   m5a.2xlarge 8/32/0.40
#

conf = get_conf('../aws.yml')
region = conf[:region]
iam_profile = conf[:inst_profile]
subnet_id = conf[:private_subnet]
keypair = conf[:keypair]

ec2 = Aws::EC2::Resource.new(region: region)

# search for offical Centos7 image in AWS marketplace
# get product code from https://wiki.centos.org/Cloud/AWS, then search using aws cli
#
# aws ec2 describe-images \
#            --owners 'aws-marketplace' \
#            --filters 'Name=product-code,Values=aw0evgkw8e5c1q413zgy5pjce' \
#            --query 'sort_by(Images, &CreationDate)[-1].[ImageId]' \
#            --output 'text'
#
# returns 
#  
#  ami-01ed306a12b7d1c96
#

{ 'mdb-tx' => 'mdb1.t.co',
  'mdb-ax' => 'mdb2.t.co'
 }.each do |role, fqdn|
  create_instances(ec2, keypair, subnet_id,
		   image_id: 'ami-01ed306a12b7d1c96',
                   instance_type: 'm5a.xlarge',
                   iam_role_profile: iam_profile,
                   startup_script: base_startup_script(set_hostname(fqdn) + extra_pkgs),
                   tags: instance_tags(role, fqdn))
end
