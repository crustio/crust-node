#!/bin/bash

scriptdir=$(cd `dirname $0`;pwd)
basedir=$(cd $scriptdir/..;pwd)
 
start()
{
	echo "Start"
    $scriptdir/install_sgx_driver.sh
    if [ $? -ne 0 ]; then
        echo "Install sgx dirver failed"
        exit 1
    fi

    $scriptdir/gen_config.sh
    if [ $? -ne 0 ]; then
        echo "Generate configuration files failed"
        exit 1
    fi
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
esac
exit 0
