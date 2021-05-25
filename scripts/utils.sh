#!/bin/bash

node_type="maxwell"
node_version="v0.10.0"
aliyun_address="registry.cn-hangzhou.aliyuncs.com"

basedir=/opt/crust/crust-node
scriptdir=$basedir/scripts
builddir=$basedir/build
configfile=$basedir/config.yaml
composeyaml=$builddir/docker-compose.yaml

function echo_c()
{
    printf "\033[0;$1m$2\033[0m\n"
}

function log_info()
{
    echo_c 33 "$1"
}

function log_success()
{
    echo_c 32 "$1"
}

function log_err()
{
    echo_c 35 "[ERROR] $1"
}

function upgrade_docker_image()
{
    local image_name=$1
    local image_tag=$node_type
    if [ x"$2" != x"" ]; then
        image_tag=$2
    fi

    local old_image=(`docker images | grep '^\b'$image_name'\b ' | grep 'latest'`)
    old_image=${old_image[2]}

    local region=`cat $basedir/etc/region.conf`
    local docker_org="crustio"
    if [ x"$region" == x"cn" ]; then
       docker_org=$aliyun_address/$docker_org
    fi

    local res=0
    docker pull $docker_org/$image_name:$image_tag
    res=$(($?|$res))
    docker tag $docker_org/$image_name:$image_tag crustio/$image_name

    if [ $res -ne 0 ]; then
        log_err "Download docker image $image_name:$image_tag failed"
        return 1
    fi

    local new_image=(`docker images | grep '^\b'$image_name'\b ' | grep 'latest'`)
    new_image=${new_image[2]}
    if [ x"$old_image" = x"$new_image" ]; then
        log_info "The current docker image $image_name ($old_image) is already the latest"
        return 1
    fi
    
    log_info "The docker image of $image_name is changed from $old_image to $new_image"

    return 0
}

check_port() {
	local port=$1
	local grep_port=`netstat -tlpn | grep "\b$port\b"`
	if [ -n "$grep_port" ]; then
		log_err "please make sure port $port is not occupied"
		return 1
	fi
}

## 0 for running, 2 for error, 1 for stop
check_docker_status()
{
	local exist=`docker inspect --format '{{.State.Running}}' $1 2>/dev/null`
	if [ x"${exist}" == x"true" ]; then
		return 0
	elif [ "${exist}" == "false" ]; then
		return 2
	else
		return 1
	fi
}