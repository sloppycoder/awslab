#!/usr/bin/env ruby

require_relative '../lib/awslab'

def instance_tags(role, fqdn)
  {
    'Project' => 't-co-dse',
    'os' => 'Linux',
    'Role' => role,
    'FQDN' => fqdn
  }
end

def set_hostname(fqdn)
  "hostnamectl set-hostname #{fqdn}"
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

{ 'dse' => 'dse.t.co' }.each do |role, fqdn|
  create_instances(ec2, keypair, subnet_id,
                   instance_type: 'm5a.xlarge',
                   iam_role_profile: iam_profile,
                   startup_script: base_startup_script(set_hostname(fqdn)),
                   tags: instance_tags(role, fqdn))
end
