#!/bin/bash

source /opt/crust/crust-node/scripts/utils.sh
source /opt/crust/crust-node/scripts/version.sh
source /opt/crust/crust-node/scripts/config.sh
source /opt/crust/crust-node/scripts/tools.sh
export EX_SWORKER_ARGS=''

########################################base################################################

start()
{
    if [ ! -f "$composeyaml" ]; then
        log_err "No configuration file, please set config"
        exit 1
    fi

    if [ x"$1" = x"" ]; then
        log_info "Start crust"

        if [ -f "$builddir/api/api_config.json" ]; then
            local chain_ws_url=`cat $builddir/api/api_config.json | jq .chain_ws_url`
            if [ x"$chain_ws_url" == x"\"ws://127.0.0.1:19944\"" ]; then
                start_chain
                if [ $? -ne 0 ]; then
                    docker-compose -f $composeyaml down
                    exit 1
                fi
            else
                log_info "API will connect to other chain: ${chain_ws_url}"
            fi
        else
            start_chain
            if [ $? -ne 0 ]; then
                docker-compose -f $composeyaml down
                exit 1
            fi
        fi

        start_sworker
        if [ $? -ne 0 ]; then
            docker-compose -f $composeyaml down
            exit 1
        fi

        start_api
        if [ $? -ne 0 ]; then
            docker-compose -f $composeyaml down
            exit 1
        fi

        start_smanager
        if [ $? -ne 0 ]; then
            docker-compose -f $composeyaml down
            exit 1
        fi

        start_ipfs
        if [ $? -ne 0 ]; then
            docker-compose -f $composeyaml down
            exit 1
        fi

        log_success "Start crust success"
        return 0
    fi

    if [ x"$1" = x"chain" ]; then
        log_info "Start chain service"
        start_chain
        if [ $? -ne 0 ]; then
            exit 1
        fi
        log_success "Start chain service success"
        return 0
    fi

    if [ x"$1" = x"api" ]; then
        log_info "Start api service"
        start_api
        if [ $? -ne 0 ]; then
            exit 1
        fi
        log_success "Start api service success"
        return 0
    fi

    if [ x"$1" = x"sworker" ]; then
        log_info "Start sworker service"
        shift
        start_sworker $@
        if [ $? -ne 0 ]; then
            exit 1
        fi
        log_success "Start sworker service success"
        return 0
    fi

    if [ x"$1" = x"smanager" ]; then
        log_info "Start smanager service"
        start_smanager
        if [ $? -ne 0 ]; then
            exit 1
        fi
        log_success "Start smanager service success"
        return 0
    fi

    if [ x"$1" = x"ipfs" ]; then
        log_info "Start ipfs service"
        start_ipfs
        if [ $? -ne 0 ]; then
            exit 1
        fi
        log_success "Start ipfs service success"
        return 0
    fi

    help
    return 1
}

stop()
{
    if [ x"$1" = x"" ]; then
        log_info "Stop crust"
        stop_chain
        stop_smanager
        stop_api
        stop_sworker
        stop_ipfs
        log_success "Stop crust success"
        return 0
    fi

    if [ x"$1" = x"chain" ]; then
        log_info "Stop chain service"
        stop_chain
        log_success "Stop chain service success"
        return 0
    fi

    if [ x"$1" = x"api" ]; then
        log_info "Stop api service"
        stop_api
        log_success "Stop api service success"
        return 0
    fi

    if [ x"$1" = x"sworker" ]; then
        log_info "Stop sworker service"
        stop_sworker
        log_success "Stop sworker service success"
        return 0
    fi

    if [ x"$1" = x"smanager" ]; then
        log_info "Stop smanager service"
        stop_smanager
        log_success "Stop smanager service success"
        return 0
    fi

    if [ x"$1" = x"ipfs" ]; then
        log_info "Stop ipfs service"
        stop_ipfs
        log_success "Stop ipfs service success"
        return 0
    fi

    help
    return 1
}

start_chain()
{
    if [ ! -f "$composeyaml" ]; then
        log_err "No configuration file, please set config"
        return 1
    fi

    check_docker_status crust
    if [ $? -eq 0 ]; then
        return 0
    fi

    local config_file=$builddir/chain/chain_config.json
    if [ x"$config_file" = x"" ]; then
        log_err "Please give right chain config file"
        return 1
    fi

    local chain_port=`cat $config_file | jq .port`

    if [ x"$chain_port" = x"" ] || [ x"$chain_port" = x"null" ]; then
        chain_port=30888
    fi

    if [ $chain_port -lt 0 ] || [ $chain_port -gt 65535 ]; then
        log_err "The range of chain port is 0 ~ 65535"
        return 1
    fi

    local res=0
    check_port $chain_port
    res=$(($?|$res))
    check_port 19933
    res=$(($?|$res))
    check_port 19944
    res=$(($?|$res))
    if [ $res -ne 0 ]; then
        return 1
    fi

    docker-compose -f $composeyaml up -d crust
    if [ $? -ne 0 ]; then
        log_err "Start crust-api failed"
        return 1
    fi
    return 0
}

stop_chain()
{
    check_docker_status crust
    if [ $? -ne 1 ]; then
        log_info "Stopping crust chain service"
        docker stop crust &>/dev/null
        docker rm crust &>/dev/null
    fi
    return 0
}

start_sworker()
{
    if [ ! -f "$composeyaml" ]; then
        log_err "No configuration file, please set config"
        return 1
    fi

    if [ -d "$builddir/sworker" ]; then
        local a_or_b=`cat $basedir/etc/sWorker.ab`
        check_docker_status crust-sworker-$a_or_b
        if [ $? -eq 0 ]; then
            return 0
        fi

        check_port 12222
        if [ $? -ne 0 ]; then
            return 1
        fi

        if [ -f "$scriptdir/install_sgx_driver.sh" ]; then
            $scriptdir/install_sgx_driver.sh
            if [ $? -ne 0 ]; then
                log_err "Install sgx dirver failed"
                return 1
            fi
        fi

        if [ ! -e "/dev/isgx" ]; then
            log_err "Your device can't install sgx dirver, please check your CPU and BIOS to determine if they support SGX."
            return 1
        fi
        EX_SWORKER_ARGS=$@ docker-compose -f $composeyaml up -d crust-sworker-$a_or_b
        if [ $? -ne 0 ]; then
            log_err "Start crust-sworker-$a_or_b failed"
            return 1
        fi
    fi
    return 0
}

stop_sworker()
{
    check_docker_status crust-sworker-a
    if [ $? -ne 1 ]; then
        log_info "Stopping crust sworker A service"
        docker stop crust-sworker-a &>/dev/null
        docker rm crust-sworker-a &>/dev/null
    fi

    check_docker_status crust-sworker-b
    if [ $? -ne 1 ]; then
        log_info "Stopping crust sworker B service"
        docker stop crust-sworker-b &>/dev/null
        docker rm crust-sworker-b &>/dev/null
    fi

    return 0
}

start_api()
{
    if [ ! -f "$composeyaml" ]; then
        log_err "No configuration file, please set config"
        return 1
    fi

    if [ -d "$builddir/sworker" ]; then
        check_docker_status crust-api
        if [ $? -eq 0 ]; then
            return 0
        fi

        check_port 56666
        if [ $? -ne 0 ]; then
            return 1
        fi

        docker-compose -f $composeyaml up -d crust-api
        if [ $? -ne 0 ]; then
            log_err "Start crust-api failed"
            return 1
        fi
    fi
    return 0
}

stop_api()
{
    check_docker_status crust-api
    if [ $? -ne 1 ]; then
        log_info "Stopping crust API service"
        docker stop crust-api &>/dev/null
        docker rm crust-api &>/dev/null
    fi
    return 0
}

start_smanager()
{
    if [ ! -f "$composeyaml" ]; then
        log_err "No configuration file, please set config"
        return 1
    fi

    if [ -d "$builddir/smanager" ]; then
        check_docker_status crust-smanager
        if [ $? -eq 0 ]; then
            return 0
        fi

        docker-compose -f $composeyaml up -d crust-smanager
        if [ $? -ne 0 ]; then
            log_err "Start crust-smanager failed"
            return 1
        fi
    fi
    return 0
}

stop_smanager()
{
    check_docker_status crust-smanager
    if [ $? -ne 1 ]; then
        log_info "Stopping crust smanager service"
        docker stop crust-smanager &>/dev/null
        docker rm crust-smanager &>/dev/null
    fi
    return 0
}

start_ipfs()
{
    if [ ! -f "$composeyaml" ]; then
        log_err "No configuration file, please set config"
        return 1
    fi

    if [ -d "$builddir/ipfs" ]; then
        check_docker_status ipfs
        if [ $? -eq 0 ]; then
            return 0
        fi

        local res=0
        check_port 4001
        res=$(($?|$res))
        check_port 5001
        res=$(($?|$res))
        check_port 37773
        res=$(($?|$res))
        if [ $res -ne 0 ]; then
            return 1
        fi

        docker-compose -f $composeyaml up -d ipfs
        if [ $? -ne 0 ]; then
            log_err "Start ipfs failed"
            return 1
        fi
    fi
    return 0
}

stop_ipfs()
{
    check_docker_status ipfs
    if [ $? -ne 1 ]; then
        log_info "Stopping ipfs service"
        docker stop ipfs &>/dev/null
        docker rm ipfs &>/dev/null
    fi
    return 0
}
 
reload() {
    if [ x"$1" = x"" ]; then
        log_info "Reload all service"
        stop
        start
        log_success "Reload all service success"
        return 0
    fi

    if [ x"$1" = x"chain" ]; then
        log_info "Reload chain service"

        stop_chain
        start_chain

        log_success "Reload chain service success"
        return 0
    fi

    if [ x"$1" = x"api" ]; then
        log_info "Reload api service"
        
        stop_api
        start_api

        log_success "Reload api service success"
        return 0
    fi

    if [ x"$1" = x"sworker" ]; then
        log_info "Reload sworker service"
        
        stop_sworker
        shift
        start_sworker $@

        log_success "Reload sworker service success"
        return 0
    fi

    if [ x"$1" = x"smanager" ]; then
        log_info "Reload smanager service"
        
        stop_smanager
        start_smanager

        log_success "Reload smanager service success"
        return 0
    fi

    if [ x"$1" = x"ipfs" ]; then
        log_info "Reload ipfs service"
        
        stop_ipfs
        start_ipfs

        log_success "Reload ipfs service success"
        return 0
    fi

    help
    return 1
}

########################################logs################################################

logs_help()
{
cat << EOF
Usage: crust logs [OPTIONS] {chain|api|sworker|sworker-a|sworker-b|smanager|ipfs}

Fetch the logs of a service

Options:
      --details        Show extra details provided to logs
  -f, --follow         Follow log output
      --since string   Show logs since timestamp (e.g. 2013-01-02T13:23:37) or relative (e.g. 42m for 42 minutes)
      --tail string    Number of lines to show from the end of the logs (default "all")
  -t, --timestamps     Show timestamps
      --until string   Show logs before a timestamp (e.g. 2013-01-02T13:23:37) or relative (e.g. 42m for 42 minutes)
EOF
}

logs()
{
    local name="${!#}"
    local array=( "$@" )
    local logs_help_flag=0
    unset "array[${#array[@]}-1]"

    if [ x"$name" == x"chain" ]; then
        check_docker_status crust
        if [ $? -eq 1 ]; then
            log_info "Service crust chain is not started now"
            return 0
        fi
        docker logs ${array[@]} -f crust
        logs_help_flag=$?
    elif [ x"$name" == x"api" ]; then
        check_docker_status crust-api
        if [ $? -eq 1 ]; then
            log_info "Service crust API is not started now"
            return 0
        fi
        docker logs ${array[@]} -f crust-api
        logs_help_flag=$?
    elif [ x"$name" == x"sworker" ]; then
        local a_or_b=`cat $basedir/etc/sWorker.ab`
        check_docker_status crust-sworker-$a_or_b
        if [ $? -eq 1 ]; then
            log_info "Service crust sworker is not started now"
            return 0
        fi
        docker logs ${array[@]} -f crust-sworker-$a_or_b
        logs_help_flag=$?
    elif [ x"$name" == x"ipfs" ]; then
        check_docker_status ipfs
        if [ $? -eq 1 ]; then
            log_info "Service ipfs is not started now"
            return 0
        fi
        docker logs ${array[@]} -f ipfs
        logs_help_flag=$?
    elif [ x"$name" == x"smanager" ]; then
        check_docker_status crust-smanager
        if [ $? -eq 1 ]; then
            log_info "Service crust smanager is not started now"
            return 0
        fi
        docker logs ${array[@]} -f crust-smanager
        logs_help_flag=$?
    elif [ x"$name" == x"sworker-a" ]; then
        check_docker_status crust-sworker-a
        if [ $? -eq 1 ]; then
            log_info "Service crust sworker-a is not started now"
            return 0
        fi
        docker logs ${array[@]} -f crust-sworker-a
        logs_help_flag=$?
    elif [ x"$name" == x"sworker-b" ]; then
        check_docker_status crust-sworker-b
        if [ $? -eq 1 ]; then
            log_info "Service crust sworker-b is not started now"
            return 0
        fi
        docker logs ${array[@]} -f crust-sworker-b
        logs_help_flag=$?
    else
        logs_help
        return 1
    fi

    if [ $logs_help_flag -ne 0 ]; then
        logs_help
        return 1
    fi
}

#######################################status################################################

status()
{
    if [ x"$1" == x"chain" ]; then
        chain_status
    elif [ x"$1" == x"api" ]; then
        api_status
    elif [ x"$1" == x"sworker" ]; then
        sworker_status
    elif [ x"$1" == x"smanager" ]; then
        smanager_status
    elif [ x"$1" == x"ipfs" ]; then
        ipfs_status
    elif [ x"$1" == x"" ]; then
        all_status
    else
        help
    fi
}

all_status()
{
    local chain_status="stop"
    local api_status="stop"
    local sworker_status="stop"
    local smanager_status="stop"
    local ipfs_status="stop"

    check_docker_status crust
    local res=$?
    if [ $res -eq 0 ]; then
        chain_status="running"
    elif [ $res -eq 2 ]; then
        chain_status="exited"
    fi

    check_docker_status crust-api
    res=$?
    if [ $res -eq 0 ]; then
        api_status="running"
    elif [ $res -eq 2 ]; then
        api_status="exited"
    fi

    local a_or_b=`cat $basedir/etc/sWorker.ab`
    check_docker_status crust-sworker-$a_or_b
    res=$?
    if [ $res -eq 0 ]; then
        sworker_status="running"
    elif [ $res -eq 2 ]; then
        sworker_status="exited"
    fi

    check_docker_status crust-smanager
    res=$?
    if [ $res -eq 0 ]; then
        smanager_status="running"
    elif [ $res -eq 2 ]; then
        smanager_status="exited"
    fi

    check_docker_status ipfs
    res=$?
    if [ $res -eq 0 ]; then
        ipfs_status="running"
    elif [ $res -eq 2 ]; then
        ipfs_status="exited"
    fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    chain                      ${chain_status}
    api                        ${api_status}
    sworker                    ${sworker_status}
    smanager                   ${smanager_status}
    ipfs                       ${ipfs_status}
-----------------------------------------
EOF
}

chain_status()
{
    local chain_status="stop"

    check_docker_status crust
    local res=$?
    if [ $res -eq 0 ]; then
        chain_status="running"
    elif [ $res -eq 2 ]; then
        chain_status="exited"
    fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    chain                      ${chain_status}
-----------------------------------------
EOF
}

api_status()
{
    local api_status="stop"

    check_docker_status crust-api
    res=$?
    if [ $res -eq 0 ]; then
        api_status="running"
    elif [ $res -eq 2 ]; then
        api_status="exited"
    fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    api                        ${api_status}
-----------------------------------------
EOF
}

sworker_status()
{
    local sworker_a_status="stop"
    local sworker_b_status="stop"
    local a_or_b=`cat $basedir/etc/sWorker.ab`

    check_docker_status crust-sworker-a
    local res=$?
    if [ $res -eq 0 ]; then
        sworker_a_status="running"
    elif [ $res -eq 2 ]; then
        sworker_a_status="exited"
    fi

    check_docker_status crust-sworker-b
    res=$?
    if [ $res -eq 0 ]; then
        sworker_b_status="running"
    elif [ $res -eq 2 ]; then
        sworker_b_status="exited"
    fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    sworker-a                  ${sworker_a_status}
    sworker-b                  ${sworker_b_status}
    main-progress              ${a_or_b}
-----------------------------------------
EOF
}

smanager_status()
{
    local smanager_status="stop"

    check_docker_status crust-smanager
    res=$?
    if [ $res -eq 0 ]; then
        smanager_status="running"
    elif [ $res -eq 2 ]; then
        smanager_status="exited"
    fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    smanager                   ${smanager_status}
-----------------------------------------
EOF
}

ipfs_status()
{
    local ipfs_status="stop"

    check_docker_status ipfs
    res=$?
    if [ $res -eq 0 ]; then
        ipfs_status="running"
    elif [ $res -eq 2 ]; then
        ipfs_status="exited"
    fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    ipfs                       ${ipfs_status}
-----------------------------------------
EOF
}

######################################main entrance############################################

help()
{
cat << EOF
Usage:
    help                                                             show help information
    version                                                          show version

    start {chain|api|sworker|smanager|ipfs}                          start all crust service
    stop {chain|api|sworker|smanager|ipfs}                           stop all crust service or stop one service

    status {chain|api|sworker|smanager|ipfs}                         check status or reload one service status
    reload {chain|api|sworker|smanager|ipfs}                         reload all service or reload one service
    logs {chain|api|sworker|sworker-a|sworker-b|smanager|ipfs}       track service logs, ctrl-c to exit. use 'crust logs help' for more details
    
    tools {...}                                                      use 'crust tools help' for more details
    config {...}                                                     configuration operations, use 'crust config help' for more details
EOF
}

case "$1" in
    version)
        version
        ;;
    start)
        shift
        start $@
        ;;
    stop)
        stop $2
        ;;
    reload)
        shift
        reload $@
        ;;
    status)
        status $2
        ;;
    logs)
        shift
        logs $@
        ;;
    config)
        shift
        config $@
        ;;
    tools)
        shift
        tools $@
        ;;
    *)
        help
esac
exit 0
