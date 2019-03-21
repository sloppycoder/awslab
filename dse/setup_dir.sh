#!/bin/bash

set -e

if [ "$1" = "" ]; then
	BASE_DIR=`pwd`
else
	BASE_DIR=$1
fi

echo # settting up DSE data directories at $BASE_DIR

declare -a arr=(
	"/var/lib/cassandra"
	"/var/log/cassandra"
        "/var/lib/spark/worker"
        "/var/lib/spark/rdd"
	"/var/log/spark"
	"/var/lib/dsefs"
	)

for dir in "${arr[@]}"
do
	if [ -d "$BASE_DIR$dir" ]; then
		rm -rf $BASE_DIR$dir
	fi

    mkdir -p $BASE_DIR$dir

    # needs root to make link from /var
    echo sudo rm -rf $dir
    echo sudo ln -s $BASE_DIR$dir $dir
done
