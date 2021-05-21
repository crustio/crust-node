#!/bin/bash

localbasedir=$(cd `dirname $0`;pwd)
localscriptdir=$localbasedir/scripts
installdir=/opt/crust/crust-node
disksdir=/opt/crust/data/disks
source $localscriptdir/utils.sh

help()
{
cat << EOF
Usage:
    help                            show help information
    --update                        update crust node
    --registry {cn|en}              use registry to accelerate docker pull
EOF
exit 0
}

install_depenencies()
{
    if [ x"$update" == x"true" ]; then
        return 0
    fi

    log_info "------------Apt update--------------"
    apt-get update
    if [ $? -ne 0 ]; then
        log_err "Apt update failed"
        exit 1
    fi

    log_info "------------Install depenencies--------------"
    apt install -y git jq curl wget build-essential kmod linux-headers-`uname -r` vim

    if [ $? -ne 0 ]; then
        log_err "Install libs failed"
        exit 1
    fi

    docker -v
    if [ $? -ne 0 ]; then
        curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
        if [ $? -ne 0 ]; then
            log_err "Install docker failed"
            exit 1
        fi
    fi

    docker-compose -v
    if [ $? -ne 0 ]; then
        apt install -y docker-compose
        if [ $? -ne 0 ]; then
            log_err "Install docker compose failed"
            exit 1
        fi
    fi
}

download_docker_images()
{
    if [ x"$update" == x"true" ]; then
        return 0
    fi

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

        docker pull $aliyun_address/crustio/crust-smanager
        res=$(($?|$res))
        docker tag $aliyun_address/crustio/crust-smanager crustio/crust-smanager
        
        docker pull $aliyun_address/crustio/go-ipfs
        res=$(($?|$res))
        docker tag $aliyun_address/crustio/go-ipfs ipfs/go-ipfs
    else
        docker pull crustio/config-generator
        res=$(($?|$res))
        docker pull crustio/crust
        res=$(($?|$res))
        docker pull crustio/crust-api
        res=$(($?|$res))
        docker pull crustio/crust-sworker
        res=$(($?|$res))
        docker pull crustio/crust-smanager
        res=$(($?|$res))
        docker pull ipfs/go-ipfs
        res=$(($?|$res))
    fi

    if [ $res -ne 0 ]; then
        log_err "Install docker failed"
        exit 1
    fi
}

create_node_paths()
{
    mkdir -p $installdir
    mkdir -p $disksdir
    chmod 777 $disksdir
    for((i=1;i<=128;i++));
    do
        mkdir -p $disksdir/$i
        chmod 777 $disksdir/$i
    done
}

install_crust_node()
{
    log_info "--------------Install crust node-------------"
    local bin_file=/usr/bin/crust
     
    if [ -d "$installdir" ] && [ -f "$bin_file" ] && [ x"$update" == x"true" ]; then
        echo "Update crust node"
        rm $bin_file
        rm -rf $installdir/scripts
        cp -r $localbasedir/scripts $installdir/
        region=`cat $localbasedir/etc/region.conf`
    else
        if [ -f "$installdir/scripts/uninstall.sh" ]; then
            echo "Uninstall old crust node"
            $installdir/scripts/uninstall.sh
        fi

        echo "Install new crust node"
        create_node_paths
        cp -r $localbasedir/etc $installdir/
        cp $localbasedir/config.yaml $installdir/
        chown root:root $installdir/config.yaml
        chmod 0600 $installdir/config.yaml
        cp -r $localbasedir/scripts $installdir/

        echo "Change crust node configurations"
        sed -i 's/en/'$region'/g' $installdir/etc/region.conf
    fi

    echo "Install crust command line tool"
    cp $localscriptdir/crust.sh /usr/bin/crust

    log_success "------------Install success-------------"
}


if [ $(id -u) -ne 0 ]; then
    log_err "Please run with sudo!"
    exit 1
fi

region="en"
update="false"

while true ; do
    case "$1" in
        --registry)
            if [ x"$2" == x"" ] || [[ x"$2" != x"cn" && x"$2" != x"en" ]]; then
                help
            fi
            region=$2
            shift 2
            ;;
        --update)
            update="true"
            shift 1
            ;;
        "")
            shift ;
            break ;;
        *)
            help
            break;
            ;;
    esac
done

install_depenencies
download_docker_images
install_crust_node
