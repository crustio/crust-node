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
docker pull crustio/config-generator
docker pull crustio/crust
docker pull crustio/crust-api
docker pull crustio/crust-sworker
docker pull crustio/karst

log_info "--------------Install crust node-------------"

echo "uninstall old crust node"
./scripts/uninstall.sh

echo "Install crust node data"
mkdir -p $installdir
cp -r scripts $installdir/
cp config.yaml $installdir/

echo "Install crust service"
cp services/crust.service /lib/systemd/system/
systemctl daemon-reload

log_success "------------Install success-------------"
