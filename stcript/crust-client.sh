#!/bin/bash

# Some configuration
crust_main_install_dir="/opt/crust"
crust_chain_main_install_dir="$crust_main_install_dir/crust"
crust_tee_main_install_dir="$crust_main_install_dir/crust-tee"
crust_api_main_install_dir="$crust_main_install_dir/crust-api"
crust_client_main_install_dir="$crust_main_install_dir/crust-client"

function help()
{
cat << EOF
Usage:
    --help      show help information
    --version   show crust-client version
    --config    show configuration files address
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

############### MAIN BODY ###############

# Command line
case "$1" in
    --config)
        config
        ;;
    --version)
        version
        ;;
    --help)
        help
        ;;
    *)
        help
        exit 1
        ;;
esac
exit 0
