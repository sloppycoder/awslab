#!/usr/bin/env ruby

require_relative '../lib/awslab'

def instance_tags(role, fqdn)
  {
    'Project' => 't-co-dse',
    'Role'    => role,
    'FQDN'    => fqdn,
    'Name'    => 'dse'
  }
end

#
# isntance types
#   m5a.large   2/ 8/0.10   vcpu/G ram/per hour usage us-west-2
#   m5a.xlarge  4/16/0.20
#   m5a.2xlarge 8/32/0.40
#

conf = get_conf('../aws.yml')
region = conf[:region]
ami_id = conf[:centos_ami_id]
vpc_id = conf[:vpc]
iam_profile = conf[:inst_profile]
keypair = conf[:private_net_keypair]

ec2 = Aws::EC2::Resource.new(region: region)
subnet = find_subnet(ec2.client, vpc_id, name: 'private')

{ 'dse' => 'dse.t.co' }.each do |role, fqdn|
  create_instances(ec2, keypair, subnet.subnet_id,
       image_id: ami_id,
       instance_type: 'm5a.large',
       iam_role_profile: iam_profile,
       startup_script: centos7_startup_script(set_hostname(fqdn) + update_r53_script),
       tags: instance_tags(role, fqdn))
end
