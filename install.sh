#!/bin/bash

localbasedir=$(cd `dirname $0`;pwd)
localscriptdir=$localbasedir/scripts
installdir=/opt/crust/crust-node
disksdir=/opt/crust/disks
datadir=/opt/crust/data
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

    sysctl -w net.core.rmem_max=2500000
}

download_docker_images()
{
    if [ x"$update" == x"true" ]; then
        return 0
    fi

    log_info "-------Download crust docker images----------"
    
    local docker_org="crustio"
    if [ x"$region" == x"cn" ]; then
       docker_org=$aliyun_address/$docker_org
    fi

    local res=0
    docker pull $docker_org/config-generator:$node_type
    res=$(($?|$res))
    docker tag $docker_org/config-generator:$node_type crustio/config-generator
        
    docker pull $docker_org/crust:$node_type
    res=$(($?|$res))
    docker tag $docker_org/crust:$node_type crustio/crust

    docker pull $docker_org/crust-api:$node_type
    res=$(($?|$res))
    docker tag $docker_org/crust-api:$node_type crustio/crust-api

    docker pull $docker_org/crust-sworker:$node_type
    res=$(($?|$res))
    docker tag $docker_org/crust-sworker:$node_type crustio/crust-sworker

    docker pull $docker_org/crust-smanager:$node_type
    res=$(($?|$res))
    docker tag $docker_org/crust-smanager:$node_type crustio/crust-smanager
        
    docker pull $docker_org/go-ipfs:$node_type
    res=$(($?|$res))
    docker tag $docker_org/go-ipfs:$node_type crustio/go-ipfs

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
    mkdir -p $datadir
    chmod 777 $datadir
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
        rm $installdir/etc/watch-chain.yaml
        cp $localbasedir/etc/watch-chain.yaml $installdir/etc/watch-chain.yaml
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
