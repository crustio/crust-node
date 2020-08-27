#!/bin/bash

installdir=/opt/crust/crust-node

if [ $(id -u) -ne 0 ]; then
    echo "Please run with sudo!"
    exit 1
fi

rm -rf $installdir
rm /lib/systemd/system/crust.service
sudo systemctl daemon-reload
