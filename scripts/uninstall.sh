#!/bin/bash

installdir=/opt/crust/crust-node
bin_file=/usr/bin/crust

if [ $(id -u) -ne 0 ]; then
    echo "Please run with sudo!"
    exit 1
fi

if [ ! -f "$myFile" ]; then
    crust stop
    rm /usr/bin/crust
fi

rm -rf $installdir
