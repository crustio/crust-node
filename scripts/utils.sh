scriptdir=$(cd `dirname $0`;pwd)
basedir=$(cd $scriptdir/..;pwd)
builddir=$basedir/build

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
    echo_c 35 "$1"
}

function upgrade_docker_image()
{
    local old_image=(`docker images | grep '^\b'$1'\b ' | grep 'latest'`)
    old_image=${old_image[3]}

    local region=`cat $basedir/etc/region.conf`
    local res=0
    if [ x"$region" == x"cn" ]; then
        local aliyun_address=registry.cn-hangzhou.aliyuncs.com
        docker pull $aliyun_address/$1
        res=$(($?|$res))
        docker tag $aliyun_address/$1 $1
    else
        docker pull $1
        res=$(($?|$res))
    fi

    if [ $res -ne 0 ]; then
        log_err "Download docker image $1 failed"
        return 1
    fi

    local new_image=(`docker images | grep '^\b'$1'\b ' | grep 'latest'`)
    new_image=${new_image[3]}
    if [ x"$old_image" = x"$new_image" ]; then
        log_info "The current docker $1 version is already the latest"
        return 1
    fi

    return 0
}

check_port() {
	port=$1
	grep_port=`netstat -tlpn | grep "\b$port\b"`
	if [ -n "$grep_port" ]; then
		echo "[ERROR] please make sure port $port is not occupied"
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
