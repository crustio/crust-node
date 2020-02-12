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
    -h,help      show help information
    -v,version   show crust-client version
EOF
}

function version()
{
    echo "crust-client version:\n\t"
    cat $crust_client_main_install_dir/VERSION
    echo "crust-chain version:\n\t"
    cat $crust_chain_main_install_dir/VERSION
    echo "crust-api version:\n\t"
    cat $crust_api_main_install_dir/VERSION
    echo "crust-tee version:\n\t"
    cat $crust_tee_main_install_dir/VERSION
}

############### MAIN BODY ###############

# Command line
case "$1" in
    -v|version)
        version
        ;;
    -h|help)
        help
        ;;
    *)
        help
        exit 1
        ;;
esac
exit 0
