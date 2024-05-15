#!/bin/bash

source /opt/crust/crust-node/scripts/utils.sh

local upgrade_pid=$(ps -ef | grep "/opt/crust/crust-node/scripts/auto_smanager.sh" | grep -v grep | awk '{print $2}')
if [ x"$upgrade_pid" = x"" ]; then
    log_info "[WARN] auto_smanager.sh script is not running! Run it now"

    if [ -f "$scriptdir/auto_smanager.sh" ]; then
        nohup $scriptdir/auto_smanager.sh &>$basedir/auto_smanager.log &
        if [ $? -ne 0 ]; then
            log_err "Start crust-smanager upgrade failed"
            return 1
        fi
    else
        log_err "auto_smanager.sh script does not exist, please check your crust-node installation"
        return 1
    fi
fi

