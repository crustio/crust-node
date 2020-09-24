#!/bin/bash

basedir=/opt/crust/crust-node
scriptdir=$basedir/scripts
builddir=$basedir/build

source $scriptdir/utils.sh
 
start()
{
	log_info "Start crust"

	local res=0
	check_port 30888
	res=$(($?|$res))
	check_port 19933
	res=$(($?|$res))
	check_port 19944
	res=$(($?|$res))
	if [ $res -ne 0 ]; then
		exit 1
	fi

	$scriptdir/gen_config.sh
	if [ $? -ne 0 ]; then
		log_err "[ERROR] Generate configuration files failed"
		exit 1
	fi

	if [ -d "$builddir/sworker" ]; then
		$scriptdir/install_sgx_driver.sh
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Install sgx dirver failed"
			exit 1
		fi
	fi

	docker-compose -f $builddir/docker-compose.yaml up -d crust
	if [ $? -ne 0 ]; then
		log_err "[ERROR] Start crust chain failed"
		exit 1
	fi

	if [ -d "$builddir/karst" ]; then
		check_port 17000
		if [ $? -ne 0 ]; then
			docker-compose -f $builddir/docker-compose.yaml down
			exit 1
		fi

		docker-compose -f $builddir/docker-compose.yaml up -d karst
		if [ $? -ne 0 ]; then
			log_err "[ERROR] Start karst failed"
			docker-compose -f $builddir/docker-compose.yaml down
			exit 1
		fi
	fi

	if [ -d "$builddir/sworker" ]; then
		local res=0
		check_port 56666
		res=$(($?|$res))
		check_port 12222
		res=$(($?|$res))
		if [ $res -ne 0 ]; then
			docker-compose -f $builddir/docker-compose.yaml down
			exit 1
		fi

		docker-compose -f $builddir/docker-compose.yaml up -d crust-api
		if [ $? -ne 0 ]; then
			docker-compose -f $builddir/docker-compose.yaml down
			log_err "[ERROR] Start crust-api failed"
			exit 1
		fi

		a_or_b=`cat $basedir/etc/sWorker.ab`
		docker-compose -f $builddir/docker-compose.yaml up -d crust-sworker-$a_or_b
		if [ $? -ne 0 ]; then
			docker-compose -f $builddir/docker-compose.yaml down
			log_err "[ERROR] Start crust-sworker-$a_or_b failed"
			exit 1
		fi

		nohup $scriptdir/upgrade.sh &>$scriptdir/upgrade.log &
		echo $! > $scriptdir/upgrade.pid
	fi

	log_success "Start crust success"
}

stop()
{
	log_info "Stop crust"

	if [ -f "$builddir/docker-compose.yaml" ]; then
		if [ -d "$builddir/sworker" ]; then
			docker-compose -f $builddir/docker-compose.yaml rm -fsv crust-sworker-a	
			docker-compose -f $builddir/docker-compose.yaml rm -fsv crust-sworker-b
			kill `cat $scriptdir/upgrade.pid`
		fi
		docker-compose -f $builddir/docker-compose.yaml down
	fi

	log_success "Stop crust success"
}
 
reload() {
	stop
	start
}

function help()
{
cat << EOF
Usage:
    help            show help information   
    start           start all crust service
    stop            stop all crust service
    reload          reload all crust service                                    
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
 
case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	reload)
		reload
		;;
	*)
		help
esac
exit 0
