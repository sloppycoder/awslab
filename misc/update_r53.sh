#!/bin/sh

# This script read an instance tag FQDN and updates Route 53 recordset with the instance's public IP address
# it will use the private IP address of the first network internet if public IP address is not assigned.
#
# It must be run inside an EC2 instance and can be called from a rc.local script during instance boot
#
# this script is published as a public gist on GitHub at
# https://gist.github.com/sloppycoder/d495a2bb2f68a847bda7286dcecc3dcf
#

update_r53()
{
    fqdn=$1
    ip_addr=$2

    # get domain portion of FQDN
    domain=${fqdn#*.*}
    if [ "$domain" = "" ]; then
        echo Cannot determine domain for $1
        return
    fi

    # query for hosted zone id of the domain. jq should be present into order for this to work
    zone_id=$( aws route53 list-hosted-zones-by-name \
               | jq --arg name "${domain}." -r '.HostedZones | .[] | select(.Name=="\($name)") | .Id' \
               | cut -d '/' -f 3 )
    if [ "$zone_id" = "" ]; then
        echo $DOMAIN not hosted on Route 53?
        return
    fi

    echo Updating hosted zone $zone_id record $1 with IP address $IP

    cat > /tmp/r53.json << EOF
{
  "Comment": "Update the A record set",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$fqdn",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "$ip_addr"
          }
        ]
      }
    }
  ]
}
EOF

    # update the route 53 recordset
    aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" --change-batch file:///tmp/r53.json

    # cleanup
    rm /tmp/r53.json
}

determine_ip()
{
    # try to determine the public IP address for the instance. fall back to private address
    # when public address is not assigned
    not_found=$( curl -s http://169.254.169.254/latest/meta-data/public-ipv4 | grep -i "not found" | wc -l )
    if [ "$not_found" = "0" ]; then
        IP=$( curl -s http://169.254.169.254/latest/meta-data/public-ipv4 )
    else
        IP=$( curl -s http://169.254.169.254/latest/meta-data/local-ipv4 )
    fi
}

get_fqdn_tag_value()
{
    instance_id=$( curl -s http://169.254.169.254/latest/meta-data/instance-id )
    region=$( curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone )
    region=${region%?}
    FQDN=$( aws ec2 describe-tags --region $region \
                                  --filters "Name=key,Values=FQDN" \
                                            "Name=resource-type,Values=instance" \
                                            "Name=resource-id,Values=$instance_id" \
              | jq -r '.Tags | .[] | .Value ' )

}

get_fqdn_tag_value
if [ "$FQDN" = "" ]; then
    echo FQDN not specified. nothing do to
    exit 1
fi

aws=$( which aws )
if [ "$aws" = "" ]; then
    echo "please install aws cli. "
    exit 1
fi

determine_ip
update_r53 $FQDN $IP
