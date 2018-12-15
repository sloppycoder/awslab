#!/usr/bin/env ruby

#
# setup a Kafka cluster machines testing
#
# 1. create a VPC with internet gateway but no public IP
# 2. create 1 zoo keeper node.
# 3. create N Kafka broker nodes
# 4. create 1 node for monitoring...install influx db etc
#

require 'aws-sdk-ec2'
require 'base64'
require 'byebug'
require_relative '../lib/awsutil'

def startup_script
  %(#!/bin/sh
yum update -y
yum install -y jq git tmux java maven
)
end

def create_workstation_instance(ec2, keypair,
                                name: 'no_name',
                                role: 'no_role',
                                iam_role_profile: nil,
                                vpc_id: nil)

  subnet = find_subnet(ec2.client, vpc_id, name: 'Private subnet')

  instance = ec2.create_instances(
    image_id: 'ami-01bbe152bf19d0289', # Amazon Linux 2 AMI (HVM) x86_64
    min_count: 1,
    max_count: 1,
    key_name: keypair,
    #    security_group_ids: [security_group_id],
    subnet_id: subnet.subnet_id,
    instance_type: 't3.small',
    placement: {
      availability_zone: subnet.availability_zone
    },
    iam_instance_profile: {
      arn: iam_role_profile
    },
    user_data: Base64.encode64(startup_script)
  )
  puts "instance #{instance.first.id} launed, please wait while it boots up"
  # Wait for the instance to be created, running, and passed status checks
  ec2.client.wait_until(:instance_status_ok, instance_ids: [instance.first.id])

  instance.batch_create_tags(tags: tags(
    'Project' => 'awslab',
    'os' => 'Linux',
    'Role' => role,
    'Name' => name
  ))

  puts "instance #{instance.first.id} running"
  instance
end

iam_profile = 'arn:aws:iam::025604691335:instance-profile/myInstaceRole'
region = 'us-west-2'
vpc_id = 'vpc-0f9bf8360078373b8'

ec2 = Aws::EC2::Resource.new(region: region)

create_workstation_instance(ec2, 'labkey', vpc_id: vpc_id, name: 'zookeeper', role: 'zookeeper')

puts %(
Instances ready
)
