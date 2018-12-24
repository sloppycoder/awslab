# Setup an AWS environment to test Apache Kafka

This repo contains instructions and scripts to setup a Kafka installation on AWS for development and testing


| folder | content |
|----| --- |
| gateway | setup a gateway instance exposed to ther internet for development. The instance is launched into an internet facing  VPC. This instance can also be used as a cloud9 development instance |
| kafka | setup a Kafka cluster for testing. The instances are launched into a private VPC that does not have public accessible IP addresses. To access the instances, a VPC peering between the internet facing VPC and this private VPC is needed|

ansible-playbook -i ../kafka/hosts.yml all.yml
