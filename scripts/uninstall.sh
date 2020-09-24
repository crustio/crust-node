#!/bin/bash

installdir=/opt/crust/crust-node

if [ $(id -u) -ne 0 ]; then
    echo "Please run with sudo!"
    exit 1
fi

sudo crust stop
rm -rf $installdir
rm /usr/bin/crust
