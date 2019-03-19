#!/bin/bash

set -e

WGET="wget --user=guru.lin@gmail.com --password Tb946060"

#declare -a arr=("/datastax-studio/datastax-studio.tar.gz")
declare -a arr=("enterprise/dse.tar.gz" "enterprise/opscenter.tar.gz" "/datastax-studio/datastax-studio.tar.gz")

for file in "${arr[@]}"
do
   CMD="$WGET  https://downloads.datastax.com/$file"
   echo $CMD
   $CMD
done

