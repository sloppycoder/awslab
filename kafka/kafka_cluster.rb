#!/usr/bin/env ruby

#
# setup a Kafka cluster machines testing
#
# 1. create n zoo keeper node.
# 2. create n Kafka broker nodes
# 3. 1 node for schema registry
# 4. 1 node for kafka connect
# 5. create 1 node for monitoring...install influx db etc.
#    this is not part of confluent platform
# 6. output a hosts.yml which can be passed to Confluent ansible playbook
#    https://github.com/confluentinc/cp-ansible
#

require 'erb'
require_relative '../lib/awslab'

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

#
# isntance types
#   m5.large   2/8/0.10   vcpu/G ram/per hour usage us-west-2
#   m5.xlarge  4/16/0.20
#   m5.2xlarge 8/32/0.40
#

iam_profile = 'arn:aws:iam::025604691335:instance-profile/myInstaceRole'
region = 'us-west-2'
subnet_id = 'subnet-0c4e4a46911040008'
keypair = 'labkey'

template = ERB.new(File.read("#{File.dirname(__FILE__)}/hosts.yml.erb"), nil, '<>')

n_zk_nodes = 1
n_broker_nodes = 3

ec2 = Aws::EC2::Resource.new(region: region)

(1..n_zk_nodes).collect { |i| "zk#{i}.t.co" }.each do |fqdn|
  create_instances(ec2, keypair, subnet_id,
                   instance_type: 'm5.large',
                   iam_role_profile: iam_profile,
                   startup_script: base_startup_script(set_hostname(fqdn)),
                   tags: instance_tags('zoo-keeper', fqdn))
end

(1..n_broker_nodes).collect { |i| "b#{i}.t.co" }.each do |fqdn|
  create_instances(ec2, keypair, subnet_id,
                   instance_type: 'm5.xlarge', # 'm5.2xlarge'
                   block_device_mappings: [
                     ebs('/dev/xvda'),
                     ebs('/dev/xvdb', type: 'st1', size: 500)
                   ],
                   iam_role_profile: iam_profile,
                   startup_script: base_startup_script(set_hostname(fqdn)) + + init_vol('/dev/xvdb'),
                   tags: instance_tags('kafka-broker', fqdn))
end

{
  'kafka-connect' => 'conn.t.co',
  'kafka-tools' => 'kt.t.co'
}.each do |role, fqdn|
  create_instances(ec2, keypair, subnet_id,
                   instance_type: 'm5.large',
                   iam_role_profile: iam_profile,
                   startup_script: base_startup_script(set_hostname(fqdn)),
                   tags: instance_tags(role, fqdn))
end

File.open('hosts.yml', 'w') do |f|
  f.write template.result
end
