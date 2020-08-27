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

status()
{
	echo "status"
}
 
restart() {
	stop
	start
}

config()
{
	echo "config"
}
 
case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	restart)
		restart
		;;
	status)
        status
		;;
    config)
        config
		;;
	*)
		echo $"Usage: $0 {start|stop|restart|status|config}"
		RES=-1
esac
exit $RES
