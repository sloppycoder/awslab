#!/usr/bin/env ruby

#
# setup a gateway machine for testing
#
#  1. create a security group ssh-http-https
#  2. launch an instance with Centos7
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

  puts "created new security group #{group_name}"
  sg
end

def instance_tags(fqdn)
  {
    'Project' => 't-co-gw',
    'Role' => 'gateway',
  }
end

conf = get_conf('../aws.yml')
region = conf[:region]
vpc_id = conf[:vpc]
ami_id = conf[:centos_ami_id]
iam_profile = conf[:inst_profile]
security_group = 'http-https-ssh'
keypair = conf[:public_net_keypair]

ec2 = Aws::EC2::Resource.new(region: region)

result = ec2.client.describe_security_groups(aws_filters('group-name' => security_group))

sg = if result.security_groups.empty?
       create_security_group(ec2, vpc_id, security_group)
     else
       result.security_groups[0]
     end

subnet = find_subnet(ec2.client, vpc_id, name: 'public', zone: 'b')

instance = create_instances(ec2, keypair, subnet.subnet_id,
                            instance_type: 't3.small',
                            image_id: ami_id,
                            iam_role_profile: iam_profile,
                            startup_script: centos7_startup_script,
                            security_group_id: sg.group_id,
                            tags: { role: 'gateway', Project: 'ktb' })

puts "waiting for instance #{instance.first.id} to be ready"

# Wait for the instance to be created, running, and passed status checks
ec2.client.wait_until(:instance_status_ok, instance_ids: [instance.first.id])

puts %(
Instance ready. To login:

    ssh centos@<instance_public_ip>

If you wish to install cloud9, run the following command first, then go to Cloud9 console to
setup the SSH environment into this machine.

   sudo yum install -y nodejs
   curl -sSL -O https://github.com/gbraad/ansible-playbooks/raw/master/playbooks/install-c9sdk.yml
   ansible-playbook install-c9sdk.yml

For nginx web server with free SSL certicate:

    sudo yum install -y nginx certbot python2-certbot-nginx


)
