#!/bin/bash

installdir=/opt/crust/crust-node

if [ $(id -u) -ne 0 ]; then
    echo "Please run with sudo!"
    exit 1
fi

echo "------------Apt update--------------"
apt-get update
if [ $? -ne 0 ]; then
    echo "Apt update failed"
    exit 1
fi

echo "------------Install depenencies--------------"
apt install -y git jq curl wget build-essential kmod linux-headers-`uname -r`
if [ $? -ne 0 ]; then
    echo "Install libs failed"
    exit 1
fi

curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
if [ $? -ne 0 ]; then
    echo "Install docker failed"
    exit 1
fi
apt install docker-compose
if [ $? -ne 0 ]; then
    echo "Install docker compose failed"
    exit 1
fi

echo "---------Uninstall old crust node------------"
./scripts/uninstall.sh

echo "--------------Install crust node-------------"
mkdir -p $installdir
cp -r scripts $installdir/
cp config.yaml $installdir/
mkdir -p $installdir/logs
touch $installdir/logs/start.log
touch $installdir/logs/stop.log
touch $installdir/logs/reload.log

echo "------------Install crust service-------------"
cp services/crust.service /lib/systemd/system/
systemctl daemon-reload
