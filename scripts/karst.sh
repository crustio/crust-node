#!/bin/bash

scriptdir=$(cd `dirname $0`;pwd)
basedir=$(cd $scriptdir/..;pwd)
builddir=$basedir/build
 
start()
{
	echo "Start"
	check_port 17000
	if [ $? -ne 0 ]; then
		exit 1
	fi

	$scriptdir/gen_config.sh
	if [ $? -ne 0 ]; then
		echo "Generate configuration files failed"
		exit 1
	fi

	if [ ! -d "$builddir/sworker" ]; then
		echo "No sworker"
		exit 1
	fi

	if [ -d "$builddir/karst" ]; then
		docker-compose -f $builddir/docker-compose.yaml up -d karst
		if [ $? -ne 0 ]; then
			echo "Start karst failed"
			exit 1
		fi
	else
		echo "Please enable karst in /opt/crust/crust-node/config.yaml"
		exit 1
	fi
}

stop()
{
	echo "Stop"
	if [ -d "$builddir/karst" ]; then
		docker-compose -f $builddir/docker-compose.yaml rm -fsv karst
	fi
}
 
reload() {
	stop
	start
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
		echo $"Usage: $0 {start|stop|reload}"
esac
exit 0
