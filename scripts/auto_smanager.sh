#!/bin/bash

source /opt/crust/crust-node/scripts/utils.sh

auto_smanager_main()
{
    log_info "Start smanager auto upgrade task."
    local rnd=$(rand 1 200)
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