#!/bin/bash

basedir=$(cd `dirname $0`;pwd)
scriptdir=$basedir/scripts
installdir=/opt/crust/crust-node
source $scriptdir/utils.sh

help()
{
cat << EOF
Usage:
    help                            show help information
    --registry {cn|en}              use registry to accelerate docker pull
EOF
exit 0
}

install_depenencies()
{
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
        apt install -y docker-compose
        if [ $? -ne 0 ]; then
            log_err "Install docker compose failed"
            exit 1
        fi
    fi
}

download_docker_images()
{
    log_info "-------Download crust docker images----------"
    res=0

    if [ x"$region" == x"cn" ]; then
        local aliyun_address=registry.cn-hangzhou.aliyuncs.com

        docker pull $aliyun_address/crustio/config-generator
        res=$(($?|$res))
        docker tag $aliyun_address/crustio/config-generator crustio/config-generator

        docker pull $aliyun_address/crustio/crust
        res=$(($?|$res))
        docker tag $aliyun_address/crustio/crust crustio/crust

        docker pull $aliyun_address/crustio/crust-api
        res=$(($?|$res))
        docker tag $aliyun_address/crustio/crust-api crustio/crust-api

        docker pull $aliyun_address/crustio/crust-sworker
        res=$(($?|$res))
        docker tag $aliyun_address/crustio/crust-sworker crustio/crust-sworker

        docker pull $aliyun_address/crustio/karst
        res=$(($?|$res))
        docker tag $aliyun_address/crustio/karst crustio/karst
    else
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
    fi

    if [ $res -ne 0 ]; then
        log_err "Install docker failed"
        exit 1
    fi
}

install_crust_node()
{
    log_info "--------------Install crust node-------------"
    
    local bin_file=/usr/bin/crust
    if [ -f "$bin_file" ]; then
        echo "uninstall old crust node"
        rm $bin_file
        rm -rf $installdir/scripts
        local upgrade_pid=$(ps -ef | grep "/opt/crust/crust-node/scripts/upgrade.sh" | grep -v grep | awk '{print $2}')
        if [ x"$upgrade_pid" != x"" ]; then
            kill -9 $upgrade_pid
            nohup $scriptdir/upgrade.sh &>$basedir/logs/upgrade.log &
            if [ $? -ne 0 ]; then
                log_err "[ERROR] Start crust-sworker upgrade failed"
                return 1
            fi
        fi
    else
        echo "Install crust node data"
        mkdir -p $installdir
        mkdir -p $installdir/logs
        cp -r $basedir/etc $installdir/
        cp $basedir/config.yaml $installdir/
    fi

    echo "Install crust scripts"
    cp -r $basedir/scripts $installdir/

    echo "Change some configurations"
    sed -i 's/en/'$region'/g' $installdir/etc/region.conf

    echo "Install crust command line tool"
    cp $scriptdir/crust.sh /usr/bin/crust

    log_success "------------Install success-------------"
}


if [ $(id -u) -ne 0 ]; then
    log_err "Please run with sudo!"
    exit 1
fi

case "$1" in
    --registry)
        if [ x"$2" == x"" ] || [[ x"$2" != x"cn" && x"$2" != x"en" ]]; then
            help
        fi

        region=$2
        ;;
    "")
        region="en"
        ;;
    *)
        help
esac

install_depenencies
download_docker_images
install_crust_node
