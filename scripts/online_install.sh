#!/bin/bash

basedir=$(cd `dirname $0`;pwd)
version=$1

if [ $(id -u) -ne 0 ]; then
    echo "Please run with sudo!"
    exit 1
fi

wget https://github.com/crustio/crust-node/archive/v$version.tar.gz
tar -xvf v$version.tar.gz
$basedir/crust-node-$version/install.sh
