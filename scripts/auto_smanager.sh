#!/bin/bash

source /opt/crust/crust-node/scripts/utils.sh

auto_smanager_main()
{
    log_info "Start smanager auto upgrade task."

    # check if the crontab contains the watcher script
    if crontab -l | grep -q "auto_smanager_watcher.sh"; then
        log_info "smanager upgrade watcher script already exist in crontab"
    else
        # insert the watcher script to crontab, which will run every 30 minutes
        (crontab -l ; echo "*/30 * * * * $scriptdir/auto_smanager_watcher.sh") | crontab -
        log_info "Add smanager upgrade watcher script to crontab successfully"
    fi

    local rnd=$(rand 1 200)
    log_info "Random sleep $rnd s"
    sleep $rnd
    while :
    do
        sleep 900
        log_info "New check Round"

        upgrade_docker_image crust-smanager $node_type
        if [ $? -ne 0 ]; then
            continue
        fi

        log_info "Found a new smanager version, ready to upgrade..."
        log_success "Image has been updated"

        check_docker_status crust-smanager
        if [ $? -eq 1 ]; then
            log_info "Service crust smanager is not started now"
            log_success "Update completed"
            continue
        fi

        docker-compose -f $composeyaml up -d crust-smanager
        if [ $? -ne 0 ]; then
            log_err "Start crust-smanager failed"
            continue
        fi

        log_success "Crust smanager service has been updated"
        log_success "Update completed"
    done
}

auto_smanager_main