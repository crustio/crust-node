#!/bin/bash

basedir=$(cd `dirname $0`;pwd)
scriptdir=$basedir/scripts
installdir=/opt/crust/crust-node
source $scriptdir/utils.sh

if [ $(id -u) -ne 0 ]; then
    log_err "Please run with sudo!"
    exit 1
fi

log_info "------------Apt update--------------"
apt-get update
if [ $? -ne 0 ]; then
    log_err "Apt update failed"
    exit 1
fi

log_info "------------Install depenencies--------------"
apt install -y git jq curl wget build-essential kmod linux-headers-`uname -r`

if [ $? -ne 0 ]; then
    log_err "Install libs failed"
    exit 1
fi

docker-compose -v
if [ $? -ne 0 ]; then
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
    if [ $? -ne 0 ]; then
        log_err "Install docker failed"
        exit 1
    fi
    apt install docker-compose
    if [ $? -ne 0 ]; then
        log_err "Install docker compose failed"
        exit 1
    fi
fi

log_info "-------Download crust docker images----------"
res=0
docker pull crustio/config-generator
res=$(($?|$res))
docker pull crustio/crust
res=$(($?|$res))
docker pull crustio/crust-api
res=$(($?|$res))
docker pull crustio/crust-sworker
res=$(($?|$res))
docker pull crustio/karst
res=$(($?|$res))
if [ $res -ne 0 ]; then
    log_err "Install docker failed"
    exit 1
fi

log_info "--------------Install crust node-------------"

echo "uninstall old crust node"
$scriptdir/uninstall.sh

echo "Install crust node data"
mkdir -p $installdir
cp -r $basedir/scripts $installdir/
cp -r $basedir/etc $installdir/
cp $basedir/config.yaml $installdir/

echo "Install crust and karst service"
cp $basedir/services/crust.service /lib/systemd/system/
cp $basedir/services/karst.service /lib/systemd/system/
systemctl daemon-reload

log_success "------------Install success-------------"
