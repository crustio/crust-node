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
    chain-lanuch-genesis <chain-start.config> <chain-identity-file>
    tee-lanuch <tee-start.json>
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

function send_grandpa_key()
{
local secret_phrase=${@:3}
curl http://localhost:$1 -H "Content-Type:application/json;charset=utf-8" -d \
 "{
    \"jsonrpc\":\"2.0\",
    \"id\":1,
    \"method\":\"author_insertKey\",
    \"params\": [
      \"gran\",
      \"$secret_phrase\",
      \"$2\"
    ]
  }"
}

function send_babe_key()
{
local secret_phrase=${@:3}
curl http://localhost:$1 -H "Content-Type:application/json;charset=utf-8" -d \
 "{
    \"jsonrpc\":\"2.0\",
    \"id\":1,
    \"method\":\"author_insertKey\",
    \"params\": [
      \"babe\",
      \"$secret_phrase\",
      \"$2\"
    ]
  }"
}

function chainLanuchGenesis()
{
    verbose INFO "Check <chain-start.config> and <chain-identity-file>" h
    if [ x"$1" = x"" ] || [ x"$2" = x"" ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR "Can't find chain-start.config!"
        exit 1
    fi
    if [ ! -f "$2" ]; then
        verbose ERROR "Can't find chain-identity-file!"
        exit 1
    fi
    
    source $2
    if [ x"$secret_phrase" = x"" ] || [ x"$public_key_sr25519" = x"" ] || [ x"$address_sr25519" = x"" ] || [ x"$public_key_ed25519" = x"" ] || [ x"$address_ed25519" = x"" ]; then
        verbose ERROR "Please give right chain-identity-file!"
        exit 1
    fi

    source $1
    if [ x"$base_path" = x"" ] || [ x"$port" = x"" ] || [ x"$ws_port" = x"" ] || [ x"$rpc_port" = x"" ] || [ x"$name" = x"" ]; then
        verbose ERROR "Please give right chain-start.config!"
        exit 1
    fi
    chain_start_stcript="/opt/crust/crust/bin/crust --base-path $base_path --chain /opt/crust/crust-client/etc/crust_chain_spec_raw.json --port $port --ws-port $ws_port --rpc-port $rpc_port --telemetry-url ws://telemetry.polkadot.io:1024 --validator --name $name"
    verbose INFO " SUCCESS" t
    
    verbose INFO "Try to kill old crust chain with same <chain_start_stcript>" h
    crust_chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
    if [ x"$crust_chain_pid" != x"" ]; then
        kill -9 $crust_chain_pid
        if [ $? -ne 0 ]; then
            # If failed by using current user, kill it using root
            sudo "kill -9 $crust_chain_pid"
        fi
    fi
    verbose INFO " SUCCESS" t

    rand_log_file=$name.temp.log
    verbose INFO "Generate temp log file $rand_log_file for crust chain without babe and grandpa key" h
    touch $rand_log_file
    verbose INFO " SUCCESS" t
    
    verbose INFO "Start up crust chain without babe and grandpa key" h
    nohup $chain_start_stcript &>$rand_log_file &
    verbose INFO " SUCCESS" t

    verbose INFO "Please wait 20s for crust chain starts completely..." n
    timeout=20
    while [ $timeout -gt 0 ]; do
        echo -e "$timeout->\c"
        ((timeout--))
        sleep 1
    done
    verbose INFO " SUCCESS" t

    verbose INFO "Send grandpa key to your chain" h
    send_grandpa_key $rpc_port $public_key_ed25519 $secret_phrase
    verbose INFO " SUCCESS" t

    verbose INFO "Send babe key to your chain" h
    send_babe_key $rpc_port $public_key_sr25519 $secret_phrase 
    verbose INFO " SUCCESS" t

    verbose INFO "Try to kill old crust chain with same <chain_start_stcript> again" h
    crust_chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
    echo $crust_chain_pid
    if [ x"$crust_chain_pid" != x"" ]; then
        kill -9 $crust_chain_pid
        if [ $? -ne 0 ]; then
            # If failed by using current user, kill it using root
            sudo "kill -9 $crust_chain_pid"
        fi
    fi
    verbose INFO " SUCCESS" t
    rm $rand_log_file

    verbose INFO "Lanuch crust chain <chain_start_stcript>" n
    sleep 2
    eval $chain_start_stcript
}

teeLanuch()
{
    verbose INFO "Check <tee-start.json>" h
    if [ x"$1" = x"" ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR "Can't find tee-start.json!"
        exit 1
    fi
    verbose INFO " SUCCESS" t

    tee_config=$(cat $1)
    echo getJsonValuesByAwk "$tee_config" "api_base_url" "null"
}

############### MAIN BODY ###############

# Command line
case "$1" in
    chain-lanuch-genesis)
        chainLanuchGenesis $2 $3
        ;;
    tee-lanuch)
        teeLanuch $2
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
