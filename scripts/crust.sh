#!/bin/bash

basedir=/opt/crust/crust-node
scriptdir=$basedir/scripts
builddir=$basedir/build

source $scriptdir/utils.sh
export EX_SWORKER_ARGS=''
 
start()
{
	log_info "Start crust"

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

	log_success "Start crust success"
}

stop()
{
	log_info "Stop crust"

	stop_chain
	stop_sworker
	stop_karst
	
	log_success "Stop crust success"
}

logs()
{
	if [ x"$1" == x"chain" ]; then
        docker logs -f crust
	elif [ x"$1" == x"api" ]; then
		docker logs -f crust-api
	elif [ x"$1" == x"sworker" ]; then
		local a_or_b=`cat $basedir/etc/sWorker.ab`
		docker logs -f crust-sworker-$a_or_b
	elif [ x"$1" == x"karst" ]; then
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
		docker stop crust
		docker rm crust
	fi
	return 0
}

start_sworker()
{
	if [ -d "$builddir/sworker" ]; then
		check_docker_status crust-api
			if [ $? -ne 1 ]; then
			return 0
		fi

		local res=0
		check_port 56666
		res=$(($?|$res))
		check_port 12222
		res=$(($?|$res))
		if [ $res -ne 0 ]; then
			return 1
		fi

		$scriptdir/install_sgx_driver.sh
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Install sgx dirver failed"
			return 1
		fi

		docker-compose -f $builddir/docker-compose.yaml up -d crust-api
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Start crust-api failed"
			return 1
		fi

		local a_or_b=`cat $basedir/etc/sWorker.ab`
		docker-compose -f $builddir/docker-compose.yaml up -d crust-sworker-$a_or_b
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Start crust-sworker-$a_or_b failed"
			return 1
		fi

		local upgrade_pid=$(ps -ef | grep "/opt/crust/crust-node/scripts/upgrade.sh" | grep -v grep | awk '{print $2}')
    	if [ x"$upgrade_pid" != x"" ]; then
        	kill -9 $upgrade_pid
    	fi

		nohup $scriptdir/upgrade.sh &>$scriptdir/upgrade.log &
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
        kill -9 $upgrade_pid
    fi

	check_docker_status crust-sworker-a
	if [ $? -ne 1 ]; then
		docker stop crust-sworker-a
		docker rm crust-sworker-a
	fi

	check_docker_status crust-sworker-b
	if [ $? -ne 1 ]; then
		docker stop crust-sworker-b
		docker rm crust-sworker-b
	fi

	check_docker_status crust-api
	if [ $? -ne 1 ]; then
		docker stop crust-api
		docker rm crust-api
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
		docker stop karst
		docker rm karst
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

	if [ x"$1" = x"sworker" ]; then
		log_info "Reload sworker service"

		log_success "Reload sworker service success"
		return 0
	fi

	if [ x"$1" = x"karst" ]; then
		log_info "Reload karst service"

		log_success "Reload karst service success"
		return 0
	fi

	help
	return 0
}

status()
{

}

help()
{
cat << EOF
Usage:
	help                            show help information
	start                           start all crust service
	stop                            stop all crust service
	status                          check status

	reload {chain|sworker|karst}    reload all service or reload one service
	logs {chain|api|sworker|karst}  track service logs, ctrl-c to exit
EOF
}

check_port() {
	port=$1
	grep_port=`netstat -tlpn | grep "\b$port\b"`
	if [ -n "$grep_port" ]; then
		echo "[ERROR] please make sure port $port is not occupied"
		return 1
	fi
}

## 0 for running, -1 for error, 1 for stop
check_docker_status()
{
	local exist=`docker inspect --format '{{.State.Running}}' $1 2>/dev/null`
	if [ x"${exist}" == x"true" ]; then
		return 0
	elif [ "${exist}" == "false" ]; then
		return -1
	else
		return 1
	fi
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
		status
		;;
	logs)
		logs $2
		;;
	*)
		help
esac
exit 0
