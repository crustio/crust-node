#!/bin/bash

# Some configuration
crust_main_install_dir="/opt/crust"
crust_chain_main_install_dir="$crust_main_install_dir/crust"
crust_tee_main_install_dir="$crust_main_install_dir/crust-tee"
crust_api_main_install_dir="$crust_main_install_dir/crust-api"
crust_client_main_install_dir="$crust_main_install_dir/crust-client"

. $crust_client_main_install_dir/stcript/utils.sh

function help()
{
cat << EOF
Usage:
    help      show help information
    version   show crust-client version
    config    show configuration files address
    chain-lanuch-genesis <chain-start-stcript> <chain-identity-file>
EOF
}

function version()
{
    echo "crust-client version:"
    cat $crust_client_main_install_dir/VERSION
    echo "crust-chain version:"
    cat $crust_chain_main_install_dir/VERSION
    echo "crust-api version:"
    cat $crust_api_main_install_dir/VERSION
    echo "crust-tee version:"
    cat $crust_tee_main_install_dir/VERSION
}

function config()
{
    echo "crust-tee configuration file address: $crust_tee_main_install_dir/etc/Config.json"
}

function chainLanuchGenesis()
{
    verbose INFO "Check <chain-start-stcript> and <chain-identity-file>" h
    if [ x"$1" = x"" ] || [ x"$2" = x"" ]; then
        help
        exit 1
    fi
    if [ ! -f "$1" ]; then
        verbose ERROR "Can't find chain-start-stcript!"
        exit 1
    fi
    if [ ! -f "$2" ]; then
        verbose ERROR "Can't find chain-identity-file!"
        exit 1
    fi
    chain_start_stcript=$(cat $1)
    source $2
    if [ x"$secret_phrase" = x"" ] || [ x"$public_key_sr25519" = x"" ] || [ x"$address_sr25519" = x"" ] || [ x"$public_key_ed25519" = x"" ] || [ x"$address_ed25519" = x"" ]; then
        verbose ERROR "Please give right chain-identity-file!"
        exit 1
    fi
    chain_start_stcript=${chain_start_stcript//"\n"/""}
    chain_start_stcript=${chain_start_stcript//'\'/""}
    verbose INFO " SUCCESS" t
    
    verbose INFO "Try to kill old crust chain with same <chain_start_stcript>" h
    crust_chain_pid=$(ps -ef | grep $chain_start_stcript | grep -v grep | awk '{print $2}')
    if [ x"$crust_chain_pid" != x"" ]; then
        kill -9 $crust_chain_pid
        if [ $? -ne 0 ]; then
            # If failed by using current user, kill it using root
            execWithExpect "kill -9 $crust_chain_pid"
        fi
    fi
    verbose INFO " SUCCESS" t

    rand_log_file="$RANDOM.log"
    while [ -f "$rand_log_file" ]
    do
        rand_log_file="$RANDOM.log"
    done     
    verbose INFO "Generate log file $rand_log_file for crust chain without babe and grandpa key" h
    touch rand_log_file
    verbose INFO " SUCCESS" t
    
    verbose INFO "Starting up crust chain without babe and grandpa key" h
    nohup eval $chain_start_stcript &>$rand_log_file &
    checkRes $? "quit"
}

############### MAIN BODY ###############

# Command line
case "$1" in
    chain-lanuch-genesis)
        chainLanuchGenesis $2 $3
        ;;
    config)
        config
        ;;
    version)
        version
        ;;
    help)
        help
        ;;
    *)
        help
        exit 1
        ;;
esac
exit 0
