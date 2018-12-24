#!/usr/bin/env ruby

#
# setup a infra machine for testing
#
#  1. create a security group ssh-http-https
#  2. launch an instance with AWS Linux 2
#  3. Update Route 53 record setup to reflect the public IP of the instance
#

require_relative '../lib/awslab'

def create_security_group(ec2, vpc_id, group_name)
  sg = ec2.create_security_group(
    group_name: group_name,
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

  sg.create_tags(tags: tags('Project' => 'awslab'))

  puts "created new security group #{group_name}"
  sg
end

def instance_tags(fqdn)
  {
    'Project' => 't-co-infra',
    'os' => 'Linux',
    'Role' => 'gateway',
    'FQDN' => fqdn
  }
end

iam_profile = 'arn:aws:iam::025604691335:instance-profile/myInstaceRole'
region = 'us-west-2'
security_group = 'ssh-http-https'
vpc_id = 'vpc-057a740f9dc10eb7b'
fqdn = 't.vino9.net'
keypair = 'aws_hayashi3'

ec2 = Aws::EC2::Resource.new(region: region)

result = ec2.client.describe_security_groups(aws_filters('group-name' => security_group))
sg = if result.security_groups.empty?
       create_security_group(ec2, vpc_id, security_group)
     else
       result.security_groups[0]
     end

# TODO: add check if instance already exists
subnet = find_subnet(ec2.client, vpc_id, name: 'Public subnet')

instance = create_instances(ec2, keypair, subnet.subnet_id,
                            instance_type: 't3.micro',
                            iam_role_profile: iam_profile,
                            startup_script: base_startup_script,
                            security_group_id: sg.group_id,
                            tags: instance_tags(fqdn))

puts "waiting for instance #{instance.first.id} to be ready"

# Wait for the instance to be created, running, and passed status checks
ec2.client.wait_until(:instance_status_ok, instance_ids: [instance.first.id])

puts %(
Instance ready. To login:

    ssh ec2-user@#{fqdn}

If you wish to install cloud9, run the following command first, then go to Cloud9 console to
setup the SSH environment into this machine.

    # essentials
    sudo amazon-linux-extras install docker -y

    # languages
    # java
    sudo yum install -y java-1.8.0-openjdk-headless maven

    # Go
    sudo amazon-linux-extras install golang1.11 -y

    # Ruby
    sudo amazon-linux-extras install ruby2.4 -y
    sudo yum install -y ruby-devel ruby-doc rubygem-bundler

    # nodejs is not in default repos. it's safer to just get binary
    # than install from epel. some packages in epel conflicts with what AWS
    # provides.
    curl http://nodejs.org/dist/v6.12.3/node-v6.12.3-linux-x64.tar.gz | tar zxf -
)
