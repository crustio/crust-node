#!/bin/bash

function help()
{
cat << EOF
    option:
        -h,help      show help information
        -v,version   show crust-client version
EOF
}

############### MAIN BODY ###############
# Some configuration
crust_main_install_dir="/opt/crust"
crust_chain_main_install_dir="$crust_main_install_dir/crust"
crust_tee_main_install_dir="$crust_main_install_dir/crust-tee"
crust_api_main_install_dir="$crust_main_install_dir/crust-api"
crust_client_main_install_dir="$crust_main_install_dir/crust-client"

# Command line
case "$1" in
    -v|version)
        echo "crust-client version:"
        cat $crust_client_main_install_dir/VERSION
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
