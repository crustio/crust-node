#!/bin/bash

scriptdir=$(cd `dirname $0`;pwd)
basedir=$(cd $scriptdir/..;pwd)
builddir=$basedir/build
 
start()
{
	echo "Start"
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
		sleep 15
		docker-compose -f $builddir/docker-compose.yaml up -d crust-api
		if [ $? -ne 0 ]; then
			echo "Start crust-api failed"
			exit 1
		fi

		a_or_b=`cat $basedir/etc/sWorker.ab`
		docker-compose -f $builddir/docker-compose.yaml up -d crust-sworker-$a_or_b
		if [ $? -ne 0 ]; then
			echo "Start crust-sworker-$a_or_b failed"
			exit 1
		fi

		nohup $scriptdir/upgrade.sh &>$scriptdir/upgrade.log &
		echo $! > $scriptdir/upgrade.pid
	fi

	if [ -d "$builddir/karst" ]; then
		docker-compose -f $builddir/docker-compose.yaml up -d karst
		if [ $? -ne 0 ]; then
			echo "Start karst failed"
			exit 1
		fi
	fi
}

stop()
{
	echo "stop"
	docker-compose -f $builddir/docker-compose.yaml down
	if [ -d "$builddir/sworker" ]; then
		kill `cat $scriptdir/upgrade.pid`
	fi
}
 
reload() {
	stop
	start
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
