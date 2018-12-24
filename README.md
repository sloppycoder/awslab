# Setup an AWS environment to test Apache Kafka

This repo contains instructions and scripts to setup a Kafka installation on AWS for development and testing


| folder | content |
|----| --- |
| gateway | setup a gateway instance exposed to ther internet for development. The instance is launched into an internet facing  VPC. This instance can also be used as a cloud9 development instance |
| kafka | setup a Kafka cluster for testing. The instances are launched into a private VPC that does not have public accessible IP addresses. To access the instances, a VPC peering between the internet facing VPC and this private VPC is needed|


## to be fixed later
```shell

# setup influxd db monitoring host

cd infra
ruby infra.rb
ansible-playbook -i "m.t.co," influxdb.yml --extra-vars "fqdn=d.vino9.net"
# create database influxdb

# install confluent platform
cd ../kafka
ruby kafka_cluster.rb
ansible -i hosts.yml all -m ping

cd  cp-ansible
ansible-playbook -i ../hosts.yml all.yml

cd ..
ansible-playbook -i hosts.yml setup_kafka.yml

# check status
ansible -i hosts.yml broker -a "sudo systemctl status confluent-kafka "
ansible -i hosts.yml broker -a "df  "

```
ansible-playbook -i ../kafka/hosts.yml all.yml
