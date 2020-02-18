#!/bin/bash

# Some configuration
crust_main_install_dir="/opt/crust"
crust_chain_main_install_dir="$crust_main_install_dir/crust"
crust_tee_main_install_dir="$crust_main_install_dir/crust-tee"
crust_api_main_install_dir="$crust_main_install_dir/crust-api"
crust_client_main_install_dir="$crust_main_install_dir/crust-client"

. $crust_client_main_install_dir/stcript/utils.sh
trap '{ echo "\nHey, you pressed Ctrl-C.  Time to quit." ; exit 1; }' INT

function help()
{
cat << EOF

Usage:
    help                                                              show help information
    version                                                           show crust-client version
    chain-lanuch-genesis <chain-lanuch.config> <chain-identity-file>  lanuch crust-chain as genesis node
    chain-lanuch-normal <chain-lanuch.config>                         lanuch crust-chain as normal node
    api-lanuch <api-lanuch.config>                                    lanuch crust-api
    ipfs-lanuch                                                       lanuch ipfs (cannot be customized for now, ipfs will be install in ~.ipfs/)      
    tee-lanuch <tee-lanuch.json>                                      lanuch crust-tee (if you set api_base_url==validator_api_base_url in config file, you need to be genesis node)
    -b <log-file> 
        with "chain-lanuch-genesis", "api-lanuch",
             "ipfs-lanuch", "tee-lanuch"                              lanuch commands will be started in backend
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
    if [ -z $1 ] || [ -z $2 ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Can't find chain-lanuch.config!"
        exit 1
    fi
    if [ ! -f "$2" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Can't find chain-identity-file!"
        exit 1
    fi
    
    source $2
    if [ x"$secret_phrase" = x"" ] || [ x"$public_key_sr25519" = x"" ] || [ x"$address_sr25519" = x"" ] || [ x"$public_key_ed25519" = x"" ] || [ x"$address_ed25519" = x"" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Please give right chain-identity-file!"
        exit 1
    fi

    source $1
    if [ x"$base_path" = x"" ] || [ x"$port" = x"" ] || [ x"$ws_port" = x"" ] || [ x"$rpc_port" = x"" ] || [ x"$name" = x"" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Please give right chain-lanuch.config!"
        exit 1
    fi
    chain_start_stcript="$crust_chain_main_install_dir/bin/crust --base-path $base_path --chain /opt/crust/crust-client/etc/crust_chain_spec_raw.json --port $port --ws-port $ws_port --rpc-port $rpc_port --validator --name $name"
    if [ ! -z $bootnodes ]; then
        chain_start_stcript="$chain_start_stcript --bootnodes=$bootnodes"
    fi
    verbose INFO " SUCCESS" t
    
    verbose INFO "Try to kill old crust chain with same <chain-lanuch.json>" h
    crust_chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
    if [ x"$crust_chain_pid" != x"" ]; then
        kill -9 $crust_chain_pid &>/dev/null
        if [ $? -ne 0 ]; then
            # If failed by using current user, kill it using root
            sudo "kill -9 $crust_chain_pid" &>/dev/null
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
    if [ x"$crust_chain_pid" != x"" ]; then
        kill -9 $crust_chain_pid &>/dev/null
        if [ $? -ne 0 ]; then
            # If failed by using current user, kill it using root
            sudo "kill -9 $crust_chain_pid" &>/dev/null
        fi
    fi
    verbose INFO " SUCCESS" t
    rm $rand_log_file &>/dev/null

    verbose WARN "You need to open the port($port) in your device to Make extranet nodes discover your node."
    sleep 1

    if [ -z "$3" ]; then
        verbose INFO "Lanuch crust chain(genesis node) with $1 configurations\n"
        eval $chain_start_stcript
    else
        nohup $chain_start_stcript &>$3 &
        sleep 1
        chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
        mv $3 $3.$chain_pid
        verbose INFO "Lanuch crust chain(genesis node) with $1 configurations in backend (pid is $chain_pid), log information will be saved in $3.$chain_pid\n"
    fi
}

chainLanuchNormal()
{
    verbose INFO "Check <chain-lanuch.config>" h
    if [ -z $1 ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Can't find chain-lanuch.config!"
        exit 1
    fi

    source $1
    if [ x"$base_path" = x"" ] || [ x"$port" = x"" ] || [ x"$ws_port" = x"" ] || [ x"$rpc_port" = x"" ] || [ x"$name" = x"" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Please give right chain-lanuch.config!"
        exit 1
    fi
    
    verbose INFO " SUCCESS" t

    chain_start_stcript="$crust_chain_main_install_dir/bin/crust --base-path $base_path --chain /opt/crust/crust-client/etc/crust_chain_spec_raw.json --pruning=archive --port $port --ws-port $ws_port --rpc-port $rpc_port --name $name"
    if [ ! -z $bootnodes ]; then
        verbose INFO "Add bootnodes($bootnodes)" h
        chain_start_stcript="$chain_start_stcript --bootnodes=$bootnodes"
        verbose INFO " SUCCESS" t
    else
        verbose ERROR "Please fill bootnodes in chain configuration!"
        exit 1
    fi

    verbose INFO "Try to kill old crust chain with same <chain-lanuch.json>" h
    crust_chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
    if [ x"$crust_chain_pid" != x"" ]; then
        kill -9 $crust_chain_pid &>/dev/null
        if [ $? -ne 0 ]; then
            # If failed by using current user, kill it using root
            sudo "kill -9 $crust_chain_pid" &>/dev/null
        fi
    fi
    verbose INFO " SUCCESS" t

    if [ x"$external_rpc_ws" = x"true" ]; then
        chain_start_stcript="$chain_start_stcript --ws-external --rpc-external --rpc-cors all"
        verbose WARN "Rpc($rpc_port) and ws($ws_port) will be external, you need open those ports in your device to exposing ports to the external network."
    fi

    sleep 1
    if [ -z "$2" ]; then
        verbose INFO "Lanuch crust chain(normal node) with $1 configurations\n"
        eval $chain_start_stcript
    else
        nohup $chain_start_stcript &>$2 &
        sleep 1
        chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
        mv $2 $2.$chain_pid
        verbose INFO "Lanuch crust chain(normal node) with $1 configurations in backend (pid is $chain_pid), log information will be saved in $2.$chain_pid\n"
    fi
}

ipfsLanuch()
{
    # TODO: Custom ipfs
    cmd_run="$crust_tee_main_install_dir/bin/ipfs daemon"
    if [ -z "$1" ]; then
        verbose INFO "Lanuch ipfs\n"
        eval $cmd_run
    else
        nohup $cmd_run &>$1 &
        ipfs_pid=$(ps -ef | grep "$cmd_run" | grep -v grep | awk '{print $2}')
        mv $1 $1.$ipfs_pid
        verbose INFO "Lanuch ipfs in backend (pid is $ipfs_pid), log information will be saved in $1.$ipfs_pid\n"
    fi
}

apiLanuch()
{
    verbose INFO "Check <api-lanuch.json>" h
    if [ x"$1" = x"" ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR "Failed!\nCan't find api-lanuch.json!"
        exit 1
    fi
    source $1
    verbose INFO " SUCCESS" t

    cmd_run="node $crust_api_main_install_dir/node_modules/.bin/ts-node $crust_api_main_install_dir/src/index.ts $crust_api_port $crust_chain_endpoint"
    if [ -z "$2" ]; then
        verbose INFO "Lanuch crust API with $1 configurations\n"
        $cmd_run
    else
        nohup $cmd_run &>$2 &
        api_pid=$(ps -ef | grep "$cmd_run" | grep -v grep | awk '{print $2}')
        mv $2 $2.$api_pid
        verbose INFO "Lanuch crust api with $1 configurations in backend (pid is $api_pid), log information will be saved in $2.$api_pid\n"
    fi
}

teeLanuch()
{
    verbose INFO "Check <tee-lanuch.json>" h
    if [ x"$1" = x"" ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR "Failed!\nCan't find tee-lanuch.json!"
        exit 1
    fi
    verbose INFO " SUCCESS" t

    tee_config=$(cat $1)
    api_base_url=$(getJsonValuesByAwk "$tee_config" "api_base_url" "null")
    validator_api_base_url=$(getJsonValuesByAwk "$tee_config" "validator_api_base_url" "null")
    if [ $api_base_url = $validator_api_base_url ]; then
         verbose WARN "TEE verifier address is the same as yourself, please confirm that you are one of genesisi nodes\n"
    fi

    cmd_run="$crust_tee_main_install_dir/bin/crust-tee -c $1"
    if [ -z "$2" ]; then
        verbose INFO "Lanuch crust TEE with $1 configurations\n"
        eval $cmd_run
    else
        nohup $cmd_run &>$2 &
        tee_pid=$(ps -ef | grep "$cmd_run" | grep -v grep | awk '{print $2}')
        mv $2 $2.$tee_pid
        verbose INFO "Lanuch tee with $1 configurations in backend (pid is $tee_pid), log information will be saved in $2.$tee_pid\n"
    fi
}

############### MAIN BODY ###############
backend_log_file=""
# Command line
while true ; do
    case "$1" in
        -b)
            backend_log_file=$2
            if [ -z $2 ]; then
                shift 1
            else
                shift 2
            fi
            ;;
        chain-lanuch-genesis)
            cmd_run="chainLanuchGenesis $2 $3"
            if [ -z $2 ] && [ -z $3 ]; then
                shift 1
            elif [ -z $3 ]; then
                shift 2
            else
                shift 3
            fi
            shift 3
            ;;
        chain-lanuch-normal)
            cmd_run="chainLanuchNormal $2"
            if [ -z $2 ]; then
                shift 1
            else
                shift 2
            fi
            ;;
        tee-lanuch)
            cmd_run="teeLanuch $2"
            if [ -z $2 ]; then
                shift 1
            else
                shift 2
            fi
            ;;
        api-lanuch)
            cmd_run="apiLanuch $2"
            if [ -z $2 ]; then
                shift 1
            else
                shift 2
            fi
            ;;
        ipfs-lanuch)
            cmd_run="ipfsLanuch"
            shift 1
            ;;
        version)
            cmd_run="version"
            break;
            ;;
        help)
            cmd_run="help"
            break;
            ;;
        --) 
            shift ;
            break ;;
        *)
            break;
            ;;
    esac
done
$cmd_run $backend_log_file
exit 0
