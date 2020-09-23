#!/bin/bash

installdir=/opt/crust/crust-node

if [ $(id -u) -ne 0 ]; then
    echo "Please run with sudo!"
    exit 1
fi

sudo systemctl stop crust
sudo systemctl stop karst
rm -rf $installdir
rm /lib/systemd/system/crust.service
rm /lib/systemd/system/karst.service
sudo systemctl daemon-reload
