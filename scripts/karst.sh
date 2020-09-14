#!/bin/bash

scriptdir=$(cd `dirname $0`;pwd)
basedir=$(cd $scriptdir/..;pwd)
builddir=$basedir/build
 
start()
{
	echo "Start"
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
	echo "Stop"
	if [ -d "$builddir/karst" ]; then
		docker-compose -f $builddir/docker-compose.yaml rm -fsv karst
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
