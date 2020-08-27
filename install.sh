#!/bin/bash

installdir=/opt/crust/crust-node

if [ $(id -u) -ne 0 ]; then
    echo "Please run with sudo!"
    exit -1
fi

mkdir -p $installdir
cp -r scripts $installdir/scripts
cp config.yaml $installdir/config
cp crust.sh /etc/init.d/crust.sh
