#!/bin/bash

source /opt/crust/crust-node/scripts/utils.sh
source /opt/crust/crust-node/scripts/version.sh
source /opt/crust/crust-node/scripts/config.sh
export EX_SWORKER_ARGS=''

########################################base################################################

start()
{
	if [ ! -f "$builddir/docker-compose.yaml" ]; then
		log_err "No configuration file, please set config"
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
	if [ ! -f "$builddir/docker-compose.yaml" ]; then
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

	docker-compose -f $builddir/docker-compose.yaml up -d crust
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
	if [ ! -f "$builddir/docker-compose.yaml" ]; then
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
		EX_SWORKER_ARGS=$@ docker-compose -f $builddir/docker-compose.yaml up -d crust-sworker-$a_or_b
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
	if [ ! -f "$builddir/docker-compose.yaml" ]; then
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

		docker-compose -f $builddir/docker-compose.yaml up -d crust-api
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
	if [ ! -f "$builddir/docker-compose.yaml" ]; then
		log_err "No configuration file, please set config"
		return 1
	fi

	if [ -d "$builddir/smanager" ]; then
		check_docker_status crust-smanager
		if [ $? -eq 0 ]; then
			return 0
		fi

		docker-compose -f $builddir/docker-compose.yaml up -d crust-smanager
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
	if [ ! -f "$builddir/docker-compose.yaml" ]; then
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

		docker-compose -f $builddir/docker-compose.yaml up -d ipfs
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

#######################################tools################################################

tools_help()
{
cat << EOF
Crust tools usage:
    help                                                       show help information
    space-info                                                 show information about data folders
    rotate-keys                                                generate session key of chain node
    upgrade-image {chain|api|smanager|ipfs|c-gen|sworker}      upgrade one docker image
    sworker-ab-upgrade                                         sworker AB upgrade
    workload                                                   show workload information
    file-info {cid}                                            show all files information or one file details
    delete-file {cid}                                          delete one file
    set-srd-ratio {ratio}                                      set SRD raito, default is 99%, range is 0% - 99%, for example 'set-srd-ratio 75'
    change-srd {number}                                        change sworker's srd capacity(GB), for example: 'change-srd 100', 'change-srd -50'
    ipfs {...}                                                 ipfs command, for example 'ipfs pin ls', 'ipfs swarm peers'
EOF
}

space_info()
{
	local data_folder_info=(`df -h /opt/crust/data | sed -n '2p'`)
cat << EOF
>>>>>> Base data folder <<<<<<
Path: /opt/crust/data
File system: ${data_folder_info[0]}
Total space: ${data_folder_info[1]}
Used space: ${data_folder_info[2]}
Avail space: ${data_folder_info[3]}
EOF

	for i in $(seq 1 128); do
		local disk_folder_info=(`df -h /opt/crust/data/disks/${i} | sed -n '2p'`)
		if [ x"${disk_folder_info[0]}" != x"${data_folder_info[0]}" ]; then
			printf "\n>>>>>> Storage folder ${i} <<<<<<\n"
			printf "Path: /opt/crust/data/disks/${i}\n"
			printf "File system: ${disk_folder_info[0]}\n"
			printf "Total space: ${disk_folder_info[1]}\n"
			printf "Used space: ${disk_folder_info[2]}\n"
			printf "Avail space: ${disk_folder_info[3]}\n"
		fi
	done

cat << EOF

PS:
1. Base data folder is used to store chain and db, 1TB SSD is recommended
2. Please mount the hard disk to storage folders, paths is from: /opt/crust/data/disks/1 ~ /opt/crust/data/disks/128
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

set_srd_ratio()
{
	if [ x"$1" == x"" ] || [[ ! $1 =~ ^[1-9][0-9]*$|^[-][1-9][0-9]*$|^0$ ]]; then 
		log_err "The input of set srd ratio must be integer number"
		tools_help
		return 1
	fi

	if [ $1 -lt 0 ] || [ $1 -gt 99 ]; then
		log_err "The range of set srd ratio is 0 ~ 99"
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

	curl -XPOST ''$base_url'/srd/ratio' -H 'backup: '$backup'' --data-raw '{"ratio" : '$1'}'
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

delete_file()
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
	curl --request POST ''$base_url'/storage/delete' --header 'Content-Type: application/json' --data-raw '{"cid":"'$1'"}'
}

upgrade_image()
{
	if [ x"$1" == x"chain" ]; then
		upgrade_docker_image crustio/crust
		if [ $? -ne 0 ]; then
			return 1
		fi
	elif [ x"$1" == x"api" ]; then
		upgrade_docker_image crustio/crust-api
		if [ $? -ne 0 ]; then
			return 1
		fi
	elif [ x"$1" == x"smanager" ]; then
		upgrade_docker_image crustio/crust-smanager
		if [ $? -ne 0 ]; then
			return 1
		fi
	elif [ x"$1" == x"ipfs" ]; then
		upgrade_docker_image ipfs/go-ipfs crustio/go-ipfs
		if [ $? -ne 0 ]; then
			return 1
		fi
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

sworker_ab_upgrade()
{
	# Check sworker
	local a_or_b=`cat $basedir/etc/sWorker.ab`
	check_docker_status crust-sworker-$a_or_b
	if [ $? -ne 0 ]; then
		log_err "Service crust sWorker is not started or exited now"
		return 1
	fi

	log_info "Start sworker A/B upgragde...."

	# Get configurations
	local config_file=$builddir/sworker/sworker_config.json
	if [ x"$config_file" = x"" ]; then
		log_err "please give right config file"
		return 1
	fi

	api_base_url=`cat $config_file | jq .chain.base_url`
	sworker_base_url=`cat $config_file | jq .base_url`

	if [ x"$api_base_url" = x"" ] || [ x"$sworker_base_url" = x"" ]; then
		log_err "please give right config file"
		return 1
	fi

	api_base_url=`echo "$api_base_url" | sed -e 's/^"//' -e 's/"$//'`
	sworker_base_url=`echo "$sworker_base_url" | sed -e 's/^"//' -e 's/"$//'`

	log_info "Read configurations success."

	# Check chain
	while :
	do
		system_health=`curl --max-time 30 $api_base_url/system/health 2>/dev/null`
		if [ x"$system_health" = x"" ]; then
			log_err "Service crust chain or api is not started or exited now"
			return 1
		fi

		is_syncing=`echo $system_health | jq .isSyncing`
		if [ x"$is_syncing" = x"" ]; then
			log_err "Service crust api dose not connet to crust chain"
			return 1
		fi

		if [ x"$is_syncing" = x"true" ]; then
			printf "\n"
			for i in $(seq 1 60); do
				printf "Crust chain is syncing, please wait 60s, now is %s\r" "${i}s"
				sleep 1
			done
			continue
		fi
		break
	done

	# Get code from chain
	local code=`curl --max-time 30 $api_base_url/swork/code 2>/dev/null`
	if [ x"$code" = x"" ]; then
		log_err "Service crust chain or api is not started or exited now"
		return 1
	fi

	if [[ ! "$code" =~ ^\"0x.* ]]; then
		log_err "Service crust chain or api is not started or exited now"
		return 1
	fi

	code=`echo ${code: 3: 64}`
	log_info "sWorker code on chain: $code"

	# Get code from sworker
	local id_info=`curl --max-time 30 $sworker_base_url/enclave/id_info 2>/dev/null`
	if [ x"$id_info" = x"" ]; then
		log_err "Please check sworker logs to find more information"
		return 1
	fi

	local mrenclave=`echo $id_info | jq .mrenclave`
	if [ x"$mrenclave" = x"" ] || [ ! ${#mrenclave} -eq 66 ]; then
		log_err "Please check sworker logs to find more information"
		return 1
	fi
	mrenclave=`echo ${mrenclave: 1: 64}`
	log_info "sWorker self code: $mrenclave"

	if [ x"$mrenclave" == x"$code" ]; then
		log_success "sWorker is already latest"
		while :
		do
			check_docker_status crust-sworker-a
			local resa=$?
			check_docker_status crust-sworker-b
			local resb=$?
			if [ $resa -eq 0 ] && [ $resb -eq 0 ] ; then
				sleep 10
				continue
			fi
			break
		done

		check_docker_status crust-sworker-a
		if [ $? -eq 0 ]; then
			local aimage=(`docker ps -a | grep 'crust-sworker-a'`)
			aimage=${aimage[1]}
			if [ x"$aimage" != x"crustio/crust-sworker:latest" ]; then
				docker tag $aimage crustio/crust-sworker:latest
			fi
		fi

		check_docker_status crust-sworker-b
		if [ $? -eq 0 ]; then
			local bimage=(`docker ps -a | grep 'crust-sworker-b'`)
			bimage=${bimage[1]}
			if [ x"$bimage" != x"crustio/crust-sworker:latest" ]; then
				docker tag $bimage crustio/crust-sworker:latest
			fi
		fi		
		return 0
	fi

	# Upgrade sworker images
	local old_image=(`docker images | grep '^\b'crustio/crust-sworker'\b ' | grep 'latest'`)
	old_image=${old_image[2]}

	local region=`cat $basedir/etc/region.conf`
	local res=0
	if [ x"$region" == x"cn" ]; then
		local aliyun_address=registry.cn-hangzhou.aliyuncs.com
		docker pull $aliyun_address/crustio/crust-sworker:latest
		res=$(($?|$res))
		docker tag $aliyun_address/crustio/crust-sworker:latest crustio/crust-sworker:latest
	else
		docker pull crustio/crust-sworker:latest
		res=$(($?|$res))
	fi

	if [ $res -ne 0 ]; then
		log_err "Download sworker docker image failed"
		return 1
	fi

	local new_image=(`docker images | grep '^\b'crustio/crust-sworker'\b ' | grep 'latest'`)
	new_image=${new_image[2]}
	if [ x"$old_image" = x"$new_image" ]; then
		log_info "The current sworker docker image is already the latest"
		return 1
	fi

	# Start A/B
	if [ x"$a_or_b" = x"a" ]; then
		a_or_b='b'
	else
		a_or_b='a'
	fi

	check_docker_status crust-sworker-a
	local resa=$?
	check_docker_status crust-sworker-b
	local resb=$?
	if [ $resa -eq 0 ] && [ $resb -eq 0 ] ; then
		log_info "sWorker A/B upgrade is already in progress"
	else
		docker stop crust-sworker-$a_or_b &>/dev/null
		docker rm crust-sworker-$a_or_b &>/dev/null
		EX_SWORKER_ARGS=--upgrade docker-compose -f $builddir/docker-compose.yaml up -d crust-sworker-$a_or_b
		if [ $? -ne 0 ]; then
			log_err "Setup new sWorker failed"
			docker tag $old_image crustio/crust-sworker:latest
			return 1
		fi
	fi

	# Change back to older image
	docker tag $old_image crustio/crust-sworker:latest
	log_info "Please do not close this program and wait patiently, ."
	log_info "If you need more information, please use other terminal to execute 'sudo crust logs sworker-a' and 'sudo crust logs sworker-b'"

	# Check A/B status
	local acc=0
	while :
	do
		printf "Sworker is upgrading, please do not close this program. Wait %s\r" "${acc}s"
		((acc++))
		sleep 1

		# Get code from sworker
		local id_info=`curl --max-time 30 $sworker_base_url/enclave/id_info 2>/dev/null`
		if [ x"$id_info" != x"" ]; then
			local mrenclave=`echo $id_info | jq .mrenclave`
			if [ x"$mrenclave" != x"" ]; then
				mrenclave=`echo ${mrenclave: 1: 64}`
				if [ x"$mrenclave" == x"$code" ]; then
					break
				fi
			fi
		fi

		# Check upgrade sworker status
		check_docker_status crust-sworker-$a_or_b
		if [ $? -ne 0 ]; then
			printf "\n"
			log_err "Sworker update failed, please use 'sudo crust logs sworker-a' and 'sudo crust logs sworker-b' to find more details"
			return 1
		fi
	done
	
	# Set new information
	docker tag $new_image crustio/crust-sworker:latest

	if [ x"$a_or_b" = x"a" ]; then
		sed -i 's/b/a/g' $basedir/etc/sWorker.ab
	else
		sed -i 's/a/b/g' $basedir/etc/sWorker.ab
	fi

	printf "\n"
	log_success "Sworker update success, setup new sworker 'crust-sworker-$a_or_b'"
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
		set-srd-ratio)
			set_srd_ratio $2
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
		delete-file)
			delete_file $2
			;;
		upgrade-image)
			upgrade_image $2
			;;
		sworker-ab-upgrade)
			sworker_ab_upgrade
			;;
		ipfs)
			shift
			ipfs_cmd $@
			;;
		*)
			tools_help
	esac
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
