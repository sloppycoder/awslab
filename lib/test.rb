#!/usr/bin/env ruby

#
# for test the functions in awslab.rb only
#

require_relative '../lib/awslab'
require 'byebug'

def instance_tags(role, fqdn)
  {
    'Project' => 'kafka',
    'os' => 'Linux',
    'Role' => role,
    'FQDN' => fqdn
  }
end

def set_hostname(fqdn)
  "hostnamectl set-hostname #{fqdn}"
end

conf = get_conf('../aws.yml')
region = conf[:region]
iam_profile = conf[:inst_profile]
subnet_id = conf[:private_subnet]
keypair = conf[:keypair]

ec2 = Aws::EC2::Resource.new(region: region)

fqdn = 'tst2.t.co'
create_instances(ec2, keypair, subnet_id,
                 instance_type: 't3.micro',
                 block_device_mappings: [
                   ebs('/dev/xvda'),
                   ebs('/dev/xvdb', type: 'st1', size: 500)
                 ],
                 iam_role_profile: iam_profile,
                 startup_script: base_startup_script(set_hostname(fqdn)) + init_vol('/dev/xvdb'),
                 tags: instance_tags('testing', fqdn))
