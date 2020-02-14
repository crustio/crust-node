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

    chain_start_stcript=${chain_start_stcript/"\\\n"/""}
    echo $chain_start_stcript
    verbose INFO "Starting up crust chain without baby and grandpa key" h
    # eval $chain_start_stcript
    verbose INFO " SUCCESS" t
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
