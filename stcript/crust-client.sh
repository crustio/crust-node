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
    help                                                              show help information
    version                                                           show crust-client version
    chain-lanuch-genesis <chain-lanuch.config> <chain-identity-file>  lanuch crust-chain as genesis node
    api-lanuch <api-lanuch.config>                                    lanuch crust-api
    ipfs-lanuch                                                       lanuch ipfs (cannot be customized for now, ipfs will be install in ~.ipfs/)      
    tee-lanuch <tee-lanuch.json>                                      lanuch crust-tee (if you set api_base_url==validator_api_base_url in config file, you need to be genesis node)
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
    verbose INFO "Check <chain-lanuch.config> and <chain-identity-file>" h
    if [ x"$1" = x"" ] || [ x"$2" = x"" ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR "Can't find chain-lanuch.config!"
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
        verbose ERROR "Please give right chain-lanuch.config!"
        exit 1
    fi
    chain_start_stcript="$crust_chain_main_install_dir/bin/crust --base-path $base_path --chain /opt/crust/crust-client/etc/crust_chain_spec_raw.json --port $port --ws-port $ws_port --rpc-port $rpc_port --telemetry-url ws://telemetry.polkadot.io:1024 --validator --name $name"
    if [ x"$bootnodes" = x"" ]; then
        chain_start_stcript="$chain_start_stcript --bootnodes=$bootnodes"
    fi
    verbose INFO " SUCCESS" t
    
    verbose INFO "Try to kill old crust chain with same <chain-lanuch.json>" h
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

    verbose INFO "Try to kill old crust chain with same <chain-lanuch.json> again" h
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

    verbose INFO "Lanuch crust chain with <chain-lanuch.json>" n
    sleep 2
    eval $chain_start_stcript
}

ipfsLanuch()
{
    # TODO: Custom ipfs
    verbose INFO "Lanuch ipfs" n
    $crust_tee_main_install_dir/bin/ipfs daemon
}

apiLanuch()
{
    trap '{ cd - ; }' INT
    verbose INFO "Check <api-lanuch.json>" h
    if [ x"$1" = x"" ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR "Can't find api-lanuch.json!"
        exit 1
    fi
    source $1
    verbose INFO " SUCCESS" t

    verbose INFO "Lanuch crust API with <api-lanuch.json>" n
    cd $crust_api_main_install_dir
    CRUST_API_PORT=$crust_api_port CRUST_CHAIN_ENDPOINT=$crust_chain_endpoint yarn start
}

teeLanuch()
{
    verbose INFO "Check <tee-lanuch.json>" h
    if [ x"$1" = x"" ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR "Can't find tee-lanuch.json!"
        exit 1
    fi
    verbose INFO " SUCCESS" t

    tee_config=$(cat $1)
    api_base_url=$(getJsonValuesByAwk "$tee_config" "api_base_url" "null")
    validator_api_base_url=$(getJsonValuesByAwk "$tee_config" "validator_api_base_url" "null")
    if [ $api_base_url = $validator_api_base_url ]; then
         verbose WARN "TEE verifier address is the same as yourself, please confirm that you are one of genesisi nodes" n $YELLOW
    fi

    verbose INFO "Lanuch crust TEE with <tee-lanuch.json>" n
    $crust_tee_main_install_dir/bin/crust-tee -c $1
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
    api-lanuch)
        apiLanuch $2
        ;;
    ipfs-lanuch)
        ipfsLanuch
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
