#!/bin/bash

curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
sudo yum install -y MariaDB-server MariaDB-client

