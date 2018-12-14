#!/usr/bin/env ruby

#
# setup a gateway machine for testing
#
#  1. create a security group ssh-http-https
#  2. launch an instance with AWS Linux 2
#  3. Update Route 53 record setup to reflect the public IP of the instance
#

require 'aws-sdk-ec2'
require 'base64'
require 'byebug'

$conf = {
  # region
  region: 'us-west-2',
  zone: 'us-west-2b',
  # network
  vpc_id: 'vpc-7812eb1d',
  subnet_id: 'subnet-b1b259c6',
  security_group: 'ssh-http-https',
  # instance
  ami: 'ami-01bbe152bf19d0289', # Amazon Linux 2 AMI (HVM) x86_64
  instance_type: 't3.small',
  iam_role_profile: 'arn:aws:iam::025604691335:instance-profile/myInstaceRole',
  # dns
  hosted_zone_id: 'ZZWPIF1B1IZ93',
  fqdn: 'd.vino9.net'
}

def project_tags(tags = [])
  [{ key: 'Project', value: 'awslab' }] + tags
end

def create_security_group(ec2)
  sg = ec2.create_security_group(
    group_name: $conf[:security_group],
    description: 'Security group for that allows only http, https and ssh',
    vpc_id: $conf[:vpc_id]
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

  sg.create_tags(tags: project_tags)

  puts "created new security group #{$conf[:security_group]}"
  sg
end

def create_dev_instance(ec2, keypair, sg_id)
  instance = ec2.create_instances(
    image_id: $conf[:ami],
    min_count: 1,
    max_count: 1,
    key_name: keypair,
    security_group_ids: [ sg_id ],
    subnet_id: $conf[:subnet_id],
    instance_type: $conf[:instance_type],
    placement: {
      availability_zone: $conf[:zone]
    },
    iam_instance_profile: {
      arn: $conf[:iam_role_profile]
    },
    user_data: startup_script
  )
  puts "instance #{instance.first.id} launed, please wait while it boots up"
  # Wait for the instance to be created, running, and passed status checks
  ec2.client.wait_until(:instance_status_ok, instance_ids: [instance.first.id])

  inst_tags = [{ key: 'Os', value: 'Linux' }, 
               { key: 'Role', value: 'Workstation' },
               { key: 'Name', value: 'workstation' }]
  instance.batch_create_tags(tags: project_tags(inst_tags))

  puts "instance #{instance.first.id} running"
  instance
end

def startup_script
  # User code that's executed when the instance starts
  script = %{#!/bin/sh

if [ -z "$1" ]; then 
    echo "IP not given...trying EC2 metadata...";
    IP=$( curl http://169.254.169.254/latest/meta-data/public-ipv4 )  
else 
    IP="$1" 
fi 
echo "IP to update: $IP"

TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
cat > ${TMPFILE} << EOF
{
  "Comment": "Update the A record set",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "#{$conf[:fqdn]}",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "$IP"
          }
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id "#{$conf[:hosted_zone_id]}" --change-batch file://"$TMPFILE"

# Clean up
# rm $TMPFILE    
}
  Base64.encode64(script)
end

client = Aws::EC2::Client.new(region: $conf[:region])
resource = Aws::EC2::Resource.new(region: $conf[:region])

result = client.describe_security_groups(filters: [{name: 'group-name', values: [$conf[:security_group]]}])
sg = result.security_groups.size > 0 ? result.security_groups[0] : create_security_group(resource)
puts "Using existing security group #{sg.group_id}"

# add check if instance already exists?
create_dev_instance(resource, 'aws_hayashi3', sg.group_id)
puts %{
Instance ready. ssh ec2-user@#{$conf[:fqdn]} to login

If you wish to install cloud9, run the following command first, then go to Cloud9 console to 
setup the SSH environment into this machine.

    sudo yum update -y
    sudo amazon-linux-extras install docker -y

Use the below command to install various languages

    # java
    sudo yum install -y java-1.8.0-openjdk-headless

    # Go
    sudo amazon-linux-extras install golang1.9 ruby2.4 -y

    # Ruby
    sudo amazon-linux-extras install ruby2.4 -y
    sudo yum install rubygem-bundler -y

You can use enable epel and get nodejs and other googies
    sudo amazon-linux-extras install epel
    
    sudo yum install epel-release -y
    sudo yum install nodejs -y

    sudo amazon-linux-extras disable epel # turn if off after you're done

}