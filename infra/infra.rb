#!/usr/bin/env ruby

#
# 1. create 1 node for monitoring...install influx db etc.
#    this is not part of confluent platform
#

require_relative '../lib/awslab'

def instance_tags(role, fqdn)
  {
    'Project' => 't-co-infra',
    'Role' => role,
    'FQDN' => fqdn
  }
end

# isntance types
#   m5.large   2/ 8/0.10   vcpu/G ram/per hour usage us-west-2
#   m5.xlarge  4/16/0.20
#   m5.2xlarge 8/32/0.40
#


conf = get_conf('../aws.yml')
region = conf[:region]
ami_id = conf[:centos_ami_id]
vpc_id = conf[:vpc]
iam_profile = conf[:inst_profile]
keypair = conf[:private_net_keypair]


ec2 = Aws::EC2::Resource.new(region: region)
subnet = find_subnet(ec2.client, vpc_id, name: 'private')

{ 'monitor' => 'm.t.co' }.each do |role, fqdn|
  create_instances(ec2, keypair, subnet.subnet_id,
                   image_id: ami_id,
                   instance_type: 'm5.xlarge',
                   iam_role_profile: iam_profile,
                   startup_script: centos7_startup_script(set_hostname(fqdn) + update_r53_script),
                   tags: instance_tags(role, fqdn))
end
