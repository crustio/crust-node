#!/bin/bash

localbasedir=$(cd `dirname $0`;pwd)
localscriptdir=$localbasedir/scripts
installdir=/opt/crust/crust-node
disksdir=/opt/crust/disks
datadir=/opt/crust/data
bin_file=/usr/bin/crust
source $localscriptdir/utils.sh

help()
{
cat << EOF
Usage:
    help                            show help information
    --update                        update crust node
    --registry {cn|en}              use registry to accelerate docker pull
    --apiKey                        subscan api key
EOF
exit 0
}

install_depenencies()
{
    if [[ x"$update" == x"true" || x"$update_ecdsa" == x"true" ]]; then
        return 0
    fi

    log_info "------------Apt update--------------"
    apt-get update
    if [ $? -ne 0 ]; then
        log_err "Apt update failed"
        exit 1
    fi

    log_info "------------Install depenencies--------------"
    apt install -y git jq curl wget build-essential kmod net-tools linux-headers-`uname -r` vim

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
    # --update-ecdsa option need to pull new docker images, so don't check update_ecdsa flag here
    if [ x"$update" == x"true" ] ; then
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

    if [[ (-d "$installdir") && (-f "$bin_file") && (x"$update" == x"true" || x"$update_ecdsa" == x"true") ]]; then
        if [ x"$update_ecdsa" == x"true" ]; then
            log_info "[ATTENTION] --update-ecdsa option would need to stop sworker and remove sworker data and disk path!"
            log_info "[ATTENTION] /opt/crust/data/sworker and /opt/crust/disks will be removed!"
            log_info "[ATTENTION] It would reset this member's storage power to 0!"

            echo ""
            read -p "Are you sure to continue? [Y/n]" response
            if [[ $response =~ ^[Yy]$ ]]; then
                echo "crust stop sworker..."
                crust stop sworker

                echo "rm -rf /opt/crust/data/sworker..."
                rm -rf /opt/crust/data/sworker

                echo "rm -rf /opt/crust/disks..."
                rm -rf /opt/crust/disks

                log_info "Data purge is done, start upgrading..."
            else
                echo "Exiting"
                exit 0
            fi
        fi
        
        echo "Update crust node"
        rm $bin_file
        rm -rf $installdir/scripts
        cp -r $localbasedir/scripts $installdir/
        rm $installdir/etc/watch-chain.yaml
        cp $localbasedir/etc/watch-chain.yaml $installdir/etc/watch-chain.yaml
    else
        if [ -f "$installdir/scripts/uninstall.sh" ]; then
            log_info "[WARN] An existing crust node is found, uninstall it would need to re-configure the node from beginning."
            log_info "[WARN] If you just want to update the crust node scripts but keep the current configuration, please rerun the script with --update option."
        
            read -p "Do you want to uninstall the existing crust node? [Y/n]" response
            if [[ $response =~ ^[Yy]$ ]]; then
                echo "Backup old crust node to ./bak"
                rm -rf $localbasedir/bak
                mkdir -p $localbasedir/bak
                cp -r $installdir $localbasedir/bak/

                echo "Uninstall old crust node"
                $installdir/scripts/uninstall.sh
            else
                echo "Exiting"
                exit 0
            fi
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

    echo "Set default SGX Attestation mode" 
    echo $default_attestation_mode > $installdir/etc/sWorker.attestation_mode

    echo "Install crust command line tool"
    cp $localscriptdir/crust.sh /usr/bin/crust
    if [ x"$SUBSCANAPIKEY" != x"" ]; then
        sed -i "/%SUBSCANAPIKEY%/ c SUBSCANAPIKEY=$SUBSCANAPIKEY" $installdir/scripts/add_spower.sh
    fi

    log_success "------------Install success-------------"
}


if [ $(id -u) -ne 0 ]; then
    log_err "Please run with sudo!"
    exit 1
fi

region="en"
update="false"
update_ecdsa="false"
default_attestation_mode=$(getSGXENCLAVEMODE)

while true ; do
    case "$1" in
        --registry)
            if [ x"$2" == x"" ] || [[ x"$2" != x"cn" && x"$2" != x"en" ]]; then
                help
            fi
            region=$2
            shift 2
            ;;
        --apiKey)
            if [ x"$2" == x"" ]; then
                help
            fi
            SUBSCANAPIKEY=$2
            shift 2
            ;;
        --update)
            if [ ! -d "$installdir" ] || [ ! -f "$bin_file" ]; then
                log_err "Crust node is not installed, --update option is not applicable."
                exit 1
            fi
            update="true"
            shift 1
            ;;
        --update-ecdsa)
            if [ ! -d "$installdir" ] || [ ! -f "$bin_file" ]; then
                log_err "Crust node is not installed, --update-ecdsa option is not applicable."
                exit 1
            fi
            if [ x"$default_attestation_mode" != x"ecdsa" ]; then
                log_err "This server doesn't support ECDSA-based DCAP attestation. --update-ecdsa option is not applicable."
                exit 1
            fi
            update_ecdsa="true"
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
