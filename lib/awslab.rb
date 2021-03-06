require 'aws-sdk-ec2'
require 'base64'
require 'json'
require 'optparse'
require 'yaml'

# convert a hash into AWS SDK's filter structure.
# e.g.
# {
#   filters: [
#     {
#       name: "vpc-id",
#       values: [
#         "vpc-a01106c2",
#       ],
#     }
#   ]
# }
def aws_filters(h)
  { filters: h.collect { |k, v| { name: k.to_s, values: [v.to_s] } } }
end

# convert a hash into AWS SDK's tag structure.
#  tag_specifications: {
#     {
#       resource_type: "instance",
#       tags: [
#              { key: 'Project', value: 'awslab' },
#             { key: 'Name', value: 'default' }
#       ]
#     }
# }
def aws_tags(resource_type, tags)
  [{
    resource_type: resource_type,
    tags: tags.collect { |k, v| { key: k.to_s, value: v.to_s } }
  }]
end

# generate EBS BlockDeviceMapping structure
def ebs(device_name, type: 'gp2', size: 8)
  {
    device_name: device_name,
    ebs: {
      delete_on_termination: true,
      volume_size: size,
      volume_type: type
    },
    no_device: ''
  }
end

def find_subnet(ec2_client, vpc_id, zone: nil, name: nil)
  result = ec2_client.describe_subnets(aws_filters('vpc-id' => vpc_id))
  selected = result.subnets.select do |subnet|
    match_zone = zone.nil? || subnet.availability_zone == ec2_client.config.region + zone
    match_name = name.nil? || !subnet.tags.select { |tag| tag.key == 'Name' && tag.value == name }.empty?
    match_zone && match_name
  end
  !selected.empty? ? selected.first : nil
end

def base_startup_script(other_commands = '')
  # this script installs some basic packages then
  # setup script to update DNS entry in route53.
  # requires an instance role that can update Route53 to work
  %(#!/bin/sh

yum update -y
yum install -y jq git tmux telnet
# this package is instaleld on AWS AMI by default, but needs to be installed explicitly for CentOS
yum install -y awscli

curl -sL https://gist.github.com/sloppycoder/d495a2bb2f68a847bda7286dcecc3dcf/raw > /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local

#{other_commands}

sleep 2
/etc/rc.d/rc.local

)
end

def centos7_startup_script(other_commands = '')
  %(#!/bin/sh

yum update -y
yum install -y git tmux telnet awscli
yum install -y epel-release
yum install -y htop jq

#{other_commands}

)
end

def set_hostname(fqdn)
  "hostnamectl set-hostname #{fqdn}"
end

def update_r53_script
%(
  curl -sL https://gist.github.com/sloppycoder/d495a2bb2f68a847bda7286dcecc3dcf/raw > /etc/rc.d/rc.local
  chmod +x /etc/rc.d/rc.local

  sleep 1
  /etc/rc.d/rc.local
)
end

# dangerous script!
def init_vol(device_name)
  return '' if device_name.nil? || device_name.empty?

  mount_dir = "/vol_#{device_name[-1]}"
  %(
if [ -b #{device_name} ]; then
    mkfs.xfs #{device_name}
    mkdir -p #{mount_dir}
    echo "#{device_name}     #{mount_dir}           xfs    defaults,noatime  1   1" >> /etc/fstab
    mount #{mount_dir}
fi
)
end

def create_instances(ec2,
                     keypair,
                     subnet_id,
                     quantity: 1,
                     image_id: nil,
                     instance_type: 't3.micro',
                     block_device_mappings: nil,
                     security_group_id: nil,
                     associate_public_ip: false,
                     iam_role_profile: nil,
                     startup_script: '',
                     tags: {})
  result = ec2.client.describe_subnets(aws_filters('subnet-id' => subnet_id))
  return nil if result.first.subnets.empty?

  options = {
    image_id: image_id,
    min_count: quantity,
    max_count: quantity,
    key_name: keypair,
    instance_type: instance_type,
    network_interfaces: [
      { device_index: 0,
        subnet_id: subnet_id,
        groups: [security_group_id],
        associate_public_ip_address: associate_public_ip
      }],
    placement: { availability_zone: result.first.subnets.first.availability_zone },
    iam_instance_profile: { arn: iam_role_profile },
    user_data: Base64.encode64(startup_script),
    tag_specifications: aws_tags('instance', tags)
  }
  options[:block_device_mappings] = block_device_mappings unless block_device_mappings.nil?

  ec2.create_instances(options)
end

def get_conf(conf_path, env = :default)
  # read as json in order to symbolize keys
  conf = JSON.parse(JSON.dump(YAML.load_file(conf_path)), symbolize_names: true)
  conf[env] || abort('unable to load AWS config file.')
end
