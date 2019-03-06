# Setup an AWS environment to test Apache Kafka

This repo contains instructions and scripts to setup a Kafka installation on AWS for development and testing.


| folder | content |
|----| --- |
| infra | Instance runs InfluxDB, Grafana, used as monitoring hosts for the Kafka cluster. |
| kafka | setup a Kafka cluster for testing. The instances are launched into a private VPC that does not have public accessible IP addresses. |


## Prerequisites
* Ruby - 2.2 or higher will work. I use 2.5
* Ansible 2.7

## Usage
```shell

# clone this repo
git submodule update –-init

# get GEMS used in the code
bundle

# setup influxd db monitoring host
cd infra
ruby infra.rb
ansible-playbook -i "m.t.co," influxdb.yml --extra-vars "fqdn=b.vino9.net"
# manually create new influx database called kafka
# install grafana plugin
# grafana-cli plugins install grafana-piechart-panel

# create instances for kafka cluster
cd ../kafka
ruby kafka_cluster.rb
ansible -i hosts.yml all -m ping

# install confluent platform
cd cp-ansible
ansible-playbook -i ../hosts.yml all.yml

# configure kafka storage and monitoring
cd ..
ansible-playbook -i hosts.yml setup_kafka.yml

# check status
ansible -i hosts.yml broker -a "sudo systemctl status confluent-kafka "
ansible -i hosts.yml broker -a "df  "

```
