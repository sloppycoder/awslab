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
require_relative '../lib/awsutil'

def update_r53_script(fqdn)
  return '' unless fqdn

  # User code that's executed when the instance starts
  %{#!/bin/sh

yum update -y
yum install -y jq git tmux

  cat > /etc/rc.d/rc.local <<END_RC_LOCAL
#!/bin/sh

FQDN="#{fqdn}"
IP=\\$( curl -s http://169.254.169.254/latest/meta-data/public-ipv4 )
DOMAIN=\\${FQDN#*.*}

cat > /tmp/r53.json << EOF
{
  "Comment": "Update the A record set",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "\\$FQDN",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "\\$IP"
          }
        ]
      }
    }
  ]
}
EOF

ZONE_ID=\\$( aws route53 list-hosted-zones-by-name | jq --arg name "\\$DOMAIN." -r '.HostedZones | .[] | select(.Name=="\\(\\$name)") | .Id' | cut -d '/' -f 3)
aws route53 change-resource-record-sets --hosted-zone-id "\\$ZONE_ID" --change-batch file:///tmp/r53.json

rm /tmp/r53.json
END_RC_LOCAL

chmod +x /etc/rc.d/rc.local
systemctl enable rc-local

/etc/rc.d/rc.local
}
end

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

def create_workstation_instance(ec2, keypair, security_group_id,
                                zone: 'b',
                                iam_role_profile: nil,
                                vpc_id: nil,
                                fqdn: nil)

  subnet_id = subnet_id_for_zone(ec2.client, vpc_id, zone)

  instance = ec2.create_instances(
    image_id: 'ami-01bbe152bf19d0289', # Amazon Linux 2 AMI (HVM) x86_64
    min_count: 1,
    max_count: 1,
    key_name: keypair,
    security_group_ids: [security_group_id],
    subnet_id: subnet_id,
    instance_type: 't3.small',
    placement: {
      availability_zone: ec2.client.config.region + zone
    },
    iam_instance_profile: {
      arn: iam_role_profile
    },
    user_data: Base64.encode64(update_r53_script(fqdn))
  )
  puts "instance #{instance.first.id} launed, please wait while it boots up"
  # Wait for the instance to be created, running, and passed status checks
  ec2.client.wait_until(:instance_status_ok, instance_ids: [instance.first.id])

  instance.batch_create_tags(tags: tags(
    'Project' => 'awslab',
    'os' => 'Linux',
    'Role' => 'workstation',
    'Name' => 'workstation'
  ))

  puts "instance #{instance.first.id} running"
  instance
end

iam_profile = 'arn:aws:iam::025604691335:instance-profile/myInstaceRole'
region = 'us-west-2'
security_group = 'ssh-http-https'
vpc_id = 'vpc-0f9bf8360078373b8'
fqdn = 'd.vino9.net'

ec2 = Aws::EC2::Resource.new(region: region)

result = ec2.client.describe_security_groups(filters: [{ name: 'group-name', values: [security_group] }])
sg = if result.security_groups.empty?
       create_security_group(ec2, vpc_id, security_group)
     else
       result.security_groups[0]
     end

# TODO: add check if instance already exists
create_workstation_instance(ec2, 'aws_hayashi3', sg.group_id,
                            iam_role_profile: iam_profile,
                            vpc_id: vpc_id,
                            fqdn: fqdn)

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
    sudo amazon-linux-extras install golang1.9 -y

    # Ruby
    sudo amazon-linux-extras install ruby2.4 -y
    sudo yum install -y ruby-devel ruby-doc rubygem-bundler

    # nodejs is not in default repos. it's safer to just get binary
    # than install from epel. some packages in epel conflicts with what AWS
    # provides.
    curl http://nodejs.org/dist/v6.12.3/node-v6.12.3-linux-x64.tar.gz | tar zxf -

)
