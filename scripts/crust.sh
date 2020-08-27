#!/bin/bash

RES=0
 
start()
{
	echo "start"
}
 
stop()
{
	echo "stop"
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
		RES=1
esac
exit $RES
