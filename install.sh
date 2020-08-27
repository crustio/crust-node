#!/bin/bash

installdir=/opt/crust/crust-node

if [ $(id -u) -ne 0 ]; then
    echo "Please run with sudo!"
    exit -1
fi

echo "Uninstall old crust node"
./scripts/uninstall.sh

echo "Install crust node"
mkdir -p $installdir
cp -r scripts $installdir/
cp config.yaml $installdir/
mkdir -p $installdir/logs
touch $installdir/logs/start.log
touch $installdir/logs/stop.log
touch $installdir/logs/reload.log

echo "Install crust service"
cp services/crust.service /lib/systemd/system/
systemctl daemon-reload
