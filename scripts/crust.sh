#!/bin/bash

basedir=/opt/crust/crust-node
scriptdir=$basedir/scripts
builddir=$basedir/build

source $scriptdir/utils.sh
export EX_SWORKER_ARGS=''

########################################base################################################

start()
{
	$scriptdir/gen_config.sh
	if [ $? -ne 0 ]; then
		log_err "[ERROR] Generate configuration files failed"
		exit 1
	fi
	
	if [ x"$1" = x"" ]; then
		log_info "Start crust"

		start_chain
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

		start_smanager
		if [ $? -ne 0 ]; then
			docker-compose -f $builddir/docker-compose.yaml down
			exit 1
		fi

		start_ipfs
		if [ $? -ne 0 ]; then
			docker-compose -f $builddir/docker-compose.yaml down
			exit 1
		fi

		log_success "Start crust success"
		return 0
	fi

	if [ x"$1" = x"chain" ]; then
		log_info "Start chain service"
		start_chain
		log_success "Start chain service success"
		return 0
	fi

	if [ x"$1" = x"api" ]; then
		log_info "Start api service"
		start_api
		log_success "Start api service success"
		return 0
	fi

	if [ x"$1" = x"sworker" ]; then
		log_info "Start sworker service"
		start_sworker
		log_success "Start sworker service success"
		return 0
	fi

	if [ x"$1" = x"smanager" ]; then
		log_info "Start smanager service"
		start_smanager
		log_success "Start smanager service success"
		return 0
	fi

	if [ x"$1" = x"ipfs" ]; then
		log_info "Start ipfs service"
		start_ipfs
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
	check_docker_status crust
	if [ $? -eq 0 ]; then
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
				log_err "[ERROR] Install sgx dirver failed"
				return 1
			fi
		fi

		if [ ! -e "/dev/isgx" ]; then
			log_err "[ERROR] Your device can't install sgx dirver, please check your CPU and BIOS to determine if they support SGX."
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

		if [ -f "$scriptdir/upgrade.sh" ]; then
			nohup $scriptdir/upgrade.sh &>$basedir/logs/upgrade.log &
			if [ $? -ne 0 ]; then
				log_err "[ERROR] Start crust-sworker upgrade failed"
				return 1
			fi
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
		if [ $? -eq 0 ]; then
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

start_smanager()
{
	if [ -d "$builddir/smanager" ]; then
		check_docker_status crust-smanager
		if [ $? -eq 0 ]; then
			return 0
		fi

		docker-compose -f $builddir/docker-compose.yaml up -d crust-smanager
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Start crust-smanager failed"
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

		docker-compose -f $builddir/docker-compose.yaml up -d ipfs
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Start ipfs failed"
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

	if [ x"$1" = x"smanager" ]; then
		log_info "Reload smanager service"
		
		stop_smanager
		$scriptdir/gen_config.sh
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Generate configuration files failed"
			exit 1
		fi
		start_smanager

		log_success "Reload smanager service success"
		return 0
	fi

	if [ x"$1" = x"ipfs" ]; then
		log_info "Reload ipfs service"
		
		stop_ipfs
		$scriptdir/gen_config.sh
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Generate configuration files failed"
			exit 1
		fi
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
Usage: crust logs [OPTIONS] {chain|api|sworker|smanager|ipfs}

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
	elif [ x"$name" == x"sworker-upshell" ]; then
		local upgrade_pid=$(ps -ef | grep "/opt/crust/crust-node/scripts/upgrade.sh" | grep -v grep | awk '{print $2}')
		if [ x"$upgrade_pid" == x"" ]; then
			log_info "Service crust sworker upgrade shell is not started now"
			return 0
		fi
		tail -f $basedir/logs/upgrade.log
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

#######################################tools################################################

tools_help()
{
cat << EOF
Crust tools usage:
    help                                                       show help information
    space-info                                                 show information about data folders
    rotate-keys                                                generate session key of chain node
    workload                                                   show workload information
    file-info {cid}                                            show all files information or one file details
    upgrade-reload {chain|api|smanager|ipfs|c-gen|sworker}     upgrade one docker image and reload the service
    change-srd {number}                                        change sworker's srd capacity(GB), for example: 'crust tools change-srd 100', 'crust tools change-srd -50'
    ipfs {...}                                                 ipfs command, for example 'ipfs pin ls', 'ipfs swarm peers'
EOF
}

space_info()
{
	local data_folder_info=(`df -h /opt/crust/data | sed -n '2p'`)
	local file_folder_info=(`df -h /opt/crust/data/files | sed -n '2p'`)
cat << EOF
-->Data folder (for chain and db)<--
Path: /opt/crust/data
File system: ${data_folder_info[0]}
Total space: ${data_folder_info[1]}
Used space: ${data_folder_info[2]}
Avail space: ${data_folder_info[3]}

-->Files folder (for ipfs and data of sworker)<--
Path: /opt/crust/data/files
File system: ${file_folder_info[0]}
Total space: ${file_folder_info[1]}
Used space: ${file_folder_info[2]}
Avail space: ${file_folder_info[3]}

PS:
1. Data folder is used to store chain and db, 500GB SSD is recommended
2. Please mount the large capacity hard disk to files folder, you can use RAID or LVM to break through the size limit of a single hard drive
3. SRD will not use all the space, it will reserve 50G of space
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
		tools_help
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

file_info()
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

	if [ x"$1" == x"" ]; then
		curl $base_url/file/info_all
	else
		curl --request POST ''$base_url'/file/info' --header 'Content-Type: application/json' --data-raw '{"cid":"'$1'"}'
	fi
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
	elif [ x"$1" == x"smanager" ]; then
		upgrade_docker_image crustio/crust-smanager
		if [ $? -ne 0 ]; then
			return 1
		fi
		reload smanager
	elif [ x"$1" == x"ipfs" ]; then
		upgrade_docker_image ipfs/go-ipfs crustio/go-ipfs
		if [ $? -ne 0 ]; then
			return 1
		fi
		reload api
	elif [ x"$1" == x"c-gen" ]; then
		upgrade_docker_image crustio/config-generator
		if [ $? -ne 0 ]; then
			return 1
		fi
	elif [ x"$1" == x"sworker" ]; then
		upgrade_docker_image crustio/crust-sworker
		if [ $? -ne 0 ]; then
			return 1
		fi
		reload sworker
	else
		tools_help
	fi
}

ipfs_cmd()
{
	check_docker_status ipfs
	if [ $? -ne 0 ]; then
		log_info "Service ipfs is not started or exited now"
		return 0
	fi
	docker exec -i ipfs ipfs $@
}

tools()
{
	case "$1" in
		space-info)
			space_info
			;;
		change-srd)
			change_srd $2
			;;
		rotate-keys)
			rotate_keys
			;;
		workload)
			workload
			;;
		file-info)
			file_info $2
			;;
		upgrade-reload)
			upgrade_reload $2
			;;
		ipfs)
			shift
			ipfs_cmd $@
			;;
		*)
			tools_help
	esac
}

#########################################config################################################

config_help()
{
cat << EOF
Crust config usage:
    help                                  show help information
    show                                  show configurations
    set                                   set configurations
EOF
}

config_show()
{
	cat $basedir/config.yaml
}

config_set_all()
{
	local chain_name=""
	read -p "Enter crust node name (default:crust-node): " chain_name
	chain_name=`echo "$chain_name"`
	if [ x"$chain_name" == x"" ]; then
		chain_name="crust-node"
	fi
	sed -i "22c \\  name: \"$chain_name\"" $basedir/config.yaml &>/dev/null
	log_success "Set crust node name: '$chain_name' successfully"

	local mode=""
	while true
	do
		read -p "Enter crust node mode from 'isolation/owner/member' (default:isolation): " mode
		mode=`echo "$mode"`
		if [ x"$mode" == x"" ]; then
			mode="isolation"
			break
		elif [ x"$mode" == x"isolation" ] || [ x"$mode" == x"owner" ] || [ x"$mode" == x"member" ]; then
			break
		else
			log_err "Input error, please input isolation/owner/member"
		fi
	done
	if [ x"$mode" == x"owner" ]; then
		sed -i '6c \\  sworker: "disable"' $basedir/config.yaml &>/dev/null
		sed -i '8c \\  smanager: "disable"' $basedir/config.yaml &>/dev/null
		sed -i '10c \\  ipfs: "disable"' $basedir/config.yaml &>/dev/null
		log_success "Set crust node mode: '$mode' successfully"
		log_success "Set configurations done"
		return
	else
		sed -i '6c \\  sworker: "enable"' $basedir/config.yaml &>/dev/null
		sed -i '8c \\  smanager: "'$mode'"' $basedir/config.yaml &>/dev/null
		sed -i '10c \\  ipfs: "enable"' $basedir/config.yaml &>/dev/null
		log_success "Set crust node mode: '$mode' successfully"
	fi

	local identity_backup=""
	while true
	do
		read -p "Enter the backup of controller account: " identity_backup
		identity_backup=`echo "$identity_backup"`
		if [ x"$identity_backup" != x"" ]; then
			break
		else
			log_err "Input error, backup can't be empty"
		fi
	done
	sed -i "15c \\  backup: '$identity_backup'" $basedir/config.yaml &>/dev/null
	log_success "Set backup successfully"

	local identity_password=""
	while true
	do
		read -p "Enter the password of controller account: " identity_password
		identity_password=`echo "$identity_password"`
		if [ x"$identity_password" != x"" ]; then
			break
		else
			log_err "Input error, password can't be empty"
		fi
	done
	sed -i '17c \\  password: "'$identity_password'"' $basedir/config.yaml &>/dev/null

	log_success "Set password successfully"
	log_success "Set configurations done"
}

config()
{
	case "$1" in
		show)
			config_show
			;;
		set)
			config_set_all
			;;
		*)
			config_help
	esac
}

######################################main entrance############################################

help()
{
cat << EOF
Usage:
    help                                         show help information
    start {chain|api|sworker|smanager|ipfs}      start all crust service
    stop {chain|api|sworker|smanager|ipfs}       stop all crust service or stop one service

    status {chain|api|sworker|smanager|ipfs}     check status or reload one service status
    reload {chain|api|sworker|smanager|ipfs}     reload all service or reload one service
    logs {chain|api|sworker|smanager|ipfs}       track service logs, ctrl-c to exit. use 'crust logs help' for more details
    
    tools {...}                                  use 'crust tools help' for more details
    config {...}                                 configuration operations, use 'crust config help' for more details         
EOF
}

case "$1" in
	start)
		start $2
		;;
	stop)
		stop $2
		;;
	reload)
		reload $2
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
