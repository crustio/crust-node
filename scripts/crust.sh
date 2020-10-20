#!/bin/bash

basedir=/opt/crust/crust-node
scriptdir=$basedir/scripts
builddir=$basedir/build

source $scriptdir/utils.sh
export EX_SWORKER_ARGS=''
 
start()
{
	check_docker_status crust
	if [ $? -ne 1 ]; then
		log_info "Crust service has started. You need to stop it, then start it"
		exit 0
	fi

	$scriptdir/gen_config.sh
	if [ $? -ne 0 ]; then
		log_err "[ERROR] Generate configuration files failed"
		exit 1
	fi

	start_chain
	if [ $? -ne 0 ]; then
		docker-compose -f $builddir/docker-compose.yaml down
		exit 1
	fi

	start_karst
	if [ $? -ne 0 ]; then
		docker-compose -f $builddir/docker-compose.yaml down
		exit 1
	fi

	start_sworker
	if [ $? -ne 0 ]; then
		docker-compose -f $builddir/docker-compose.yaml down
		exit 1
	fi

	start_api
	if [ $? -ne 0 ]; then
		docker-compose -f $builddir/docker-compose.yaml down
		exit 1
	fi

	log_success "Start crust success"
}

stop()
{
	stop_chain
	stop_api
	stop_sworker
	stop_karst
	
	log_success "Stop crust success"
}

logs()
{
	if [ x"$1" == x"chain" ]; then
		check_docker_status crust
		if [ $? -eq 1 ]; then
			log_info "Service crust chain is not started now"
			return 0
		fi
		docker logs -f crust
	elif [ x"$1" == x"api" ]; then
		check_docker_status crust-api
		if [ $? -eq 1 ]; then
			log_info "Service crust API is not started now"
			return 0
		fi
		docker logs -f crust-api
	elif [ x"$1" == x"sworker" ]; then
		local a_or_b=`cat $basedir/etc/sWorker.ab`
		check_docker_status crust-sworker-$a_or_b
		if [ $? -eq 1 ]; then
			log_info "Service crust sworker is not started now"
			return 0
		fi
		docker logs -f crust-sworker-$a_or_b
	elif [ x"$1" == x"karst" ]; then
		check_docker_status karst
		if [ $? -eq 1 ]; then
			log_info "Service karst is not started now"
			return 0
		fi
		docker logs -f karst
	else
		help
	fi
}

start_chain()
{
	check_docker_status crust
	if [ $? -ne 1 ]; then
		return 0
	fi

	local res=0
	check_port 30888
	res=$(($?|$res))
	check_port 19933
	res=$(($?|$res))
	check_port 19944
	res=$(($?|$res))
	if [ $res -ne 0 ]; then
		return 1
	fi

	docker-compose -f $builddir/docker-compose.yaml up -d crust
	if [ $? -ne 0 ]; then
		log_err "[ERROR] Start crust-api failed"
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
	if [ -d "$builddir/sworker" ]; then
		local a_or_b=`cat $basedir/etc/sWorker.ab`
		check_docker_status crust-sworker-$a_or_b
		if [ $? -ne 1 ]; then
			return 0
		fi

		check_port 12222
		if [ $? -ne 0 ]; then
			return 1
		fi

		$scriptdir/install_sgx_driver.sh
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Install sgx dirver failed"
			return 1
		fi

		docker-compose -f $builddir/docker-compose.yaml up -d crust-sworker-$a_or_b
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Start crust-sworker-$a_or_b failed"
			return 1
		fi

		local upgrade_pid=$(ps -ef | grep "/opt/crust/crust-node/scripts/upgrade.sh" | grep -v grep | awk '{print $2}')
		if [ x"$upgrade_pid" != x"" ]; then
			kill -9 $upgrade_pid
		fi

		nohup $scriptdir/upgrade.sh &>$basedir/logs/upgrade.log &
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Start crust-sworker upgrade failed"
			return 1
		fi
	fi
	return 0
}

stop_sworker()
{
	local upgrade_pid=$(ps -ef | grep "/opt/crust/crust-node/scripts/upgrade.sh" | grep -v grep | awk '{print $2}')
	if [ x"$upgrade_pid" != x"" ]; then
		log_info "Stopping crust sworker upgrade shell"
		kill -9 $upgrade_pid &>/dev/null
	fi

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
	if [ -d "$builddir/sworker" ]; then
		check_docker_status crust-api
		if [ $? -ne 1 ]; then
			return 0
		fi

		check_port 56666
		if [ $? -ne 0 ]; then
			return 1
		fi

		docker-compose -f $builddir/docker-compose.yaml up -d crust-api
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Start crust-api failed"
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

start_karst()
{
	if [ -d "$builddir/karst" ]; then
		check_docker_status karst
			if [ $? -ne 1 ]; then
			return 0
		fi

		check_port 17000
		if [ $? -ne 0 ]; then
			return 1
		fi

		docker-compose -f $builddir/docker-compose.yaml up -d karst
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Start karst failed"
			return 1
		fi
	fi
}

stop_karst()
{
	check_docker_status karst
	if [ $? -ne 1 ]; then
		log_info "Stopping karst service"
		docker stop karst &>/dev/null
		docker rm karst &>/dev/null
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
		$scriptdir/gen_config.sh
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Generate configuration files failed"
			exit 1
		fi
		start_chain

		log_success "Reload chain service success"
		return 0
	fi

	if [ x"$1" = x"api" ]; then
		log_info "Reload api service"
		
		stop_api
		$scriptdir/gen_config.sh
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Generate configuration files failed"
			exit 1
		fi
		start_api

		log_success "Reload api service success"
		return 0
	fi

	if [ x"$1" = x"sworker" ]; then
		log_info "Reload sworker service"
		
		stop_sworker
		$scriptdir/gen_config.sh
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Generate configuration files failed"
			exit 1
		fi
		start_sworker

		log_success "Reload sworker service success"
		return 0
	fi

	if [ x"$1" = x"karst" ]; then
		log_info "Reload karst service"

		stop_karst
		$scriptdir/gen_config.sh
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Generate configuration files failed"
			exit 1
		fi
		start_karst

		log_success "Reload karst service success"
		return 0
	fi

	help
	return 0
}

status()
{
	if [ x"$1" == x"chain" ]; then
		chain_status
	elif [ x"$1" == x"api" ]; then
		api_status
	elif [ x"$1" == x"sworker" ]; then
		sworker_status
	elif [ x"$1" == x"karst" ]; then
		karst_status
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
	local karst_status="stop"

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
	
	check_docker_status karst
	res=$?
	if [ $res -eq 0 ]; then
		karst_status="running"
	elif [ $res -eq 2 ]; then
		karst_status="exited"
	fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    chain                      ${chain_status}
    api                        ${api_status}
    sworker                    ${sworker_status}
    karst                      ${karst_status}
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
	local upgrade_shell_status="stop"
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

	local upgrade_pid=$(ps -ef | grep "/opt/crust/crust-node/scripts/upgrade.sh" | grep -v grep | awk '{print $2}')
	if [ x"$upgrade_pid" != x"" ]; then
		upgrade_shell_status="running->${upgrade_pid}"
	fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    sworker-a                  ${sworker_a_status}
    sworker-b                  ${sworker_b_status}
    upgrade-shell              ${upgrade_shell_status}
    main-progress              ${a_or_b}
-----------------------------------------
EOF
}

karst_status()
{
	local karst_status="stop"
	
	check_docker_status karst
	res=$?
	if [ $res -eq 0 ]; then
		karst_status="running"
	elif [ $res -eq 2 ]; then
		karst_status="exited"
	fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    karst                      ${karst_status}
-----------------------------------------
EOF
}

help()
{
cat << EOF
Usage:
    help                            	show help information
    start                           	start all crust service
    stop                            	stop all crust service

    status {chain|api|sworker|karst}    check status or reload one service status
    reload {chain|api|sworker|karst}    reload all service or reload one service
    logs {chain|api|sworker|karst}      track service logs, ctrl-c to exit
    tools {...}                         use 'crust tools help' for more details
EOF
}

tools_help()
{
cat << EOF
crust tools usage:
    help                                      show help information
    rotate-keys                               generate session key of chain node
    workload                                  show workload information
    upgrade-reload {chain|api|karst|c-gen}    upgrade one docker image and reload the service
    change-srd {number}                       change sworker's srd capacity(GB), for example: 'crust tools change-srd 100', 'crust tools change-srd -50'
    show-files                                show all stored files
    clear-outdate-files                       clean up expired files
EOF
}

rotate_keys()
{
	check_docker_status crust
	if [ $? -ne 0 ]; then
		log_info "Service chain is not started or exited now"
		return 0
	fi

	local res=`curl -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "author_rotateKeys", "params":[]}' http://localhost:19933 2>/dev/null`
	session_key=`echo $res | jq .result`
	if [ x"$session_key" = x"" ]; then
		log_err "Generate session key failed"
		return 1
	fi
	echo $session_key
}

change_srd()
{
	if [ x"$1" == x"" ] || [[ ! $1 =~ ^[1-9][0-9]*$|^[-][1-9][0-9]*$|^0$ ]]; then 
		log_err "The input of srd change must be integer number"
		return 1
	fi

	if [ x"$1" == x"0" ]; then 
		log_err "Srd change number can't be zero"
		return 1
	fi

	local a_or_b=`cat $basedir/etc/sWorker.ab`
	check_docker_status crust-sworker-$a_or_b
	if [ $? -ne 0 ]; then
		log_info "Service crust sworker is not started or exited now"
		return 0
	fi

	if [ ! -f "$builddir/sworker/sworker_config.json" ]; then
		log_err "No sworker configuration file"
		return 1
	fi

	local backup=`cat $builddir/sworker/sworker_config.json | jq .chain.backup`
	backup=${backup//\\/}
	backup=${backup%?}
	backup=${backup:1}

	local base_url=`cat $builddir/sworker/sworker_config.json | jq .base_url`
	base_url=${base_url%?}
	base_url=${base_url:1}

	curl -XPOST ''$base_url'/srd/change' -H 'backup: '$backup'' --data-raw '{"change" : '$1'}'
}

workload()
{
	local a_or_b=`cat $basedir/etc/sWorker.ab`
	check_docker_status crust-sworker-$a_or_b
	if [ $? -ne 0 ]; then
		log_info "Service crust sworker is not started or exited now"
		return 0
	fi

	local base_url=`cat $builddir/sworker/sworker_config.json | jq .base_url`
	base_url=${base_url%?}
	base_url=${base_url:1}

	curl $base_url/workload
}

upgrade_reload()
{
	if [ x"$1" == x"chain" ]; then
		upgrade_docker_image crustio/crust
		if [ $? -ne 0 ]; then
			return 1
		fi
		reload chain
	elif [ x"$1" == x"api" ]; then
		upgrade_docker_image crustio/crust-api
		if [ $? -ne 0 ]; then
			return 1
		fi
		reload api
	elif [ x"$1" == x"karst" ]; then
		upgrade_docker_image crustio/karst
		if [ $? -ne 0 ]; then
			return 1
		fi
		reload karst
	elif [ x"$1" == x"c-gen" ]; then
		upgrade_docker_image crustio/config-generator
		if [ $? -ne 0 ]; then
			return 1
		fi
	else
		tools_help
	fi
}

show_files()
{
	check_docker_status karst
	if [ $? -ne 0 ]; then
		log_info "Service karst is not started or exited now"
		return 0
	fi
	docker exec -it karst /bin/bash -c 'karst list'
}

clear_outdate_files()
{
	check_docker_status karst
	if [ $? -ne 0 ]; then
		log_info "Service karst is not started or exited now"
		return 0
	fi
	docker exec -it karst /bin/bash -c 'karst delete'
}

tools()
{
	case "$1" in
		change-srd)
			change_srd $2
			;;
		rotate-keys)
			rotate_keys
			;;
		workload)
			workload
			;;
		upgrade-reload)
			upgrade_reload $2
			;;
		show-files)
			show_files
			;;
		clear-outdate-files)
			clear_outdate_files
			;;
		*)
			tools_help
	esac
}
 
case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	reload)
		reload $2
		;;
	status)
		status $2
		;;
	logs)
		logs $2
		;;
	tools)
		shift
		tools $@
		;;
	*)
		help
esac
exit 0
