#!/bin/bash

basedir=/opt/crust/crust-node
scriptdir=$basedir/scripts
builddir=$basedir/build
 
start()
{
	echo "Start"

	local res=0
	check_port 30333
	res=$(($?|$res))
	check_port 9933
	res=$(($?|$res))
	check_port 9944
	res=$(($?|$res))
	if [ $res -ne 0 ]; then
		exit 1
	fi

	$scriptdir/gen_config.sh
	if [ $? -ne 0 ]; then
		echo "Generate configuration files failed"
		exit 1
	fi

	if [ -d "$builddir/sworker" ]; then
		$scriptdir/install_sgx_driver.sh
		if [ $? -ne 0 ]; then
			echo "Install sgx dirver failed"
			exit 1
		fi
	fi

	docker-compose -f $builddir/docker-compose.yaml up -d crust
	if [ $? -ne 0 ]; then
		echo "Start crust chain failed"
		exit 1
	fi

	if [ -d "$builddir/sworker" ]; then
		local res=0
		check_port 56666
		res=$(($?|$res))
		check_port 12222
		res=$(($?|$res))
		if [ $res -ne 0 ]; then
			docker-compose -f $builddir/docker-compose.yaml rm -fsv crust
			exit 1
		fi

		docker-compose -f $builddir/docker-compose.yaml up -d crust-api
		if [ $? -ne 0 ]; then
			docker-compose -f $builddir/docker-compose.yaml rm -fsv crust
			echo "Start crust-api failed"
			exit 1
		fi

		a_or_b=`cat $basedir/etc/sWorker.ab`
		docker-compose -f $builddir/docker-compose.yaml up -d crust-sworker-$a_or_b
		if [ $? -ne 0 ]; then
			docker-compose -f $builddir/docker-compose.yaml rm -fsv crust
			docker-compose -f $builddir/docker-compose.yaml rm -fsv crust-api
			echo "Start crust-sworker-$a_or_b failed"
			exit 1
		fi

		nohup $scriptdir/upgrade.sh &>$scriptdir/upgrade.log &
		echo $! > $scriptdir/upgrade.pid
	fi

	if [ -d "$builddir/karst" ]; then
		check_port 17000
		docker-compose -f $builddir/docker-compose.yaml up -d karst
		if [ $? -ne 0 ]; then
			echo "Start karst failed"
			docker-compose -f $builddir/docker-compose.yaml down
			exit 1
		fi
	fi
}

stop()
{
	echo "Stop"
	if [ -d "$builddir/sworker" ]; then
		kill `cat $scriptdir/upgrade.pid`
	fi
	docker-compose -f $builddir/docker-compose.yaml down
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
		echo "Please make sure port $port is not occupied"
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
