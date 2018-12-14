#!/usr/bin/env ruby

#
# setup a gateway machine for testing
#
#  1. create a security group ssh-http-https
#  2. launch an instance with AWS Linux 2
#  3. Update Route 53 record setup to reflect the public IP of the instance
#

require 'aws-sdk-ec2'
require 'aws-sdk-route53'
require 'byebug'

REGION = 'us-west-2'.freeze
VPC_ID = 'vpc-7812eb1d'.freeze
SECURITY_GROUP = 'ssh-http-https'.freeze
TAGS = [{ key: 'Project', value: 'awslab' }].freeze

def create_sg(region, vpc_id, name, tags = nil)
  ec2 = Aws::EC2::Resource.new(region: region)
  sg = ec2.create_security_group(
    group_name: name,
    description: 'Security group for that allows only http, https and ssh',
    vpc_id: vpc_id
  )

  sg.authorize_ingress(
    group_id: sg.group_id,
    ip_permissions:
      [22, 80, 443].collect do |port|
        {
          ip_protocol: 'tcp',
          from_port: port,
          to_port: port,
          ip_ranges: [{ cidr_ip: '0.0.0.0/0' }]
        }
      end
  )

  puts "security group #{name} created"

  debugger
  sg.create_tags(tags: tags) unless tags.nil? || tags.empty?
  sg
rescue Aws::EC2::Errors::InvalidGroupDuplicate
  puts "security group #{name} already exists"
end

create_sg(REGION, VPC_ID, SECURITY_GROUP, TAGS)
