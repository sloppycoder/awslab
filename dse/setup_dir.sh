#!/bin/bash

set -e 

BASE_DIR=/apps/dse/data

makedir () {
    mkdir -p $1
    chown datastax:datastax $1
}

makedir $BASE_DIR

declare -a arr=("/var/lib/cassandra" "/var/log/cassandra" "/var/log/spark" "/var/lib/spark" "/var/lib/dsefs")
for dir in "${arr[@]}"
do
    makedir $BASE_DIR$dir
    echo sudo ln -s $BASE_DIR$dir $dir
done
