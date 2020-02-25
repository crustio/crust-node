#!/bin/bash

# Some configuration
crust_main_install_dir="/opt/crust"
crust_chain_main_install_dir="$crust_main_install_dir/crust"
crust_tee_main_install_dir="$crust_main_install_dir/crust-tee"
crust_api_main_install_dir="$crust_main_install_dir/crust-api"
crust_client_main_install_dir="$crust_main_install_dir/crust-client"

ipfs_bin=$crust_tee_main_install_dir/bin/ipfs
swarm_key=$crust_client_main_install_dir/etc/swarm.key

. $crust_client_main_install_dir/stcript/utils.sh
trap '{ echo "\nHey, you pressed Ctrl-C.  Time to quit." ; exit 1; }' INT

function help()
{
cat << EOF

Usage:
    help                                                                show help information   
    version                                                             show crust-client version   
    chain-launch-genesis <chain-launch.config> <chain-identity-file>    launch crust-chain as a genesis node   
    chain-launch-normal <chain-launch.config>                           launch crust-chain as a normal node
    chain-launch-validator <chain-launch.config>                        launch crust-chain as a validator node
    api-launch <api-launch.config>                                      launch crust-api
    ipfs-launch <ipfs-launch>                                           launch ipfs      
    tee-launch <tee-launch.json>                                        launch crust-tee (if you set 
                                                                            api_base_url==validator_api_base_url
                                                                            in config file, you need to be genesis node)
    -b <log-file>                                                       launch commands will be started in backend
                                                                            with "chain-launch-genesis", "chain-launch-normal",
                                                                            "chain-launch-validator", "api-launch", "ipfs-launch",
                                                                            "tee-launch"                                                       
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

function send_im_online_key()
{
local secret_phrase=${@:3}
curl http://localhost:$1 -H "Content-Type:application/json;charset=utf-8" -d \
 "{
    \"jsonrpc\":\"2.0\",
    \"id\":1,
    \"method\":\"author_insertKey\",
    \"params\": [
      \"imon\",
      \"$secret_phrase\",
      \"$2\"
    ]
  }"
}

function send_authority_discovery_key()
{
local secret_phrase=${@:3}
curl http://localhost:$1 -H "Content-Type:application/json;charset=utf-8" -d \
 "{
    \"jsonrpc\":\"2.0\",
    \"id\":1,
    \"method\":\"author_insertKey\",
    \"params\": [
      \"audi\",
      \"$secret_phrase\",
      \"$2\"
    ]
  }"
}

# params are <base_path> <rpc_port> <name> <chain_start_stcript>
function get_rotate_keys()
{
    local rotate_keys=""
    local chain_start_stcript=${@:4}
    local rotate_keys_file_path=$1/chains/rotate_keys.json
    local rotate_keys_file_dir=$1/chains/
    local rpc_port=$2
    local rand_log_file=$3.temp.log

    if [ -f "$rotate_keys_file_path" ]; then
        verbose INFO "Get rotate keys from $rotate_keys_file_path" h
        rotate_keys=$(cat $rotate_keys_file_path)
        verbose INFO " SUCCESS" t
    else
        verbose INFO "Generate temp log file $rand_log_file for crust chain node without rotate keys" h
        mkdir -p $rotate_keys_file_dir
        touch $rand_log_file
        verbose INFO " SUCCESS" t
    
        verbose INFO "Start up crust chain node without rotate keys" h
        nohup $chain_start_stcript &>$rand_log_file &
        verbose INFO " SUCCESS" t

        verbose INFO "Please wait 20s for crust chain node starts completely..." n
        timeout=20
        while [ $timeout -gt 0 ]; do
            echo -e "$timeout->\c"
            ((timeout--))
            sleep 1
        done
        verbose INFO " SUCCESS" t

        verbose INFO "Call rpc to generate rotate keys for your chain node" h
        local result=$(curl -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "author_rotateKeys", "params":[]}' http://localhost:$rpc_port)
        rotate_keys=$(getJsonValuesByAwk "$result" "result" "null")
        verbose INFO " SUCCESS" t

        verbose INFO "Save rotate keys result into $rotate_keys_file_path" h
        touch $rotate_keys_file_path
        echo $rotate_keys > $rotate_keys_file_path
       
        verbose INFO " SUCCESS" t

        verbose INFO "Kill old crust chain with same <chain-launch.json>" h
        local crust_chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
        if [ x"$crust_chain_pid" != x"" ]; then
            kill -9 $crust_chain_pid &>/dev/null
            if [ $? -ne 0 ]; then
                # If failed by using current user, kill it using root
                sudo "kill -9 $crust_chain_pid" &>/dev/null
            fi
        fi
        rm $rand_log_file $>/dev/null
        verbose INFO " SUCCESS" t
    fi
    
    verbose WARN "Please go to chain web page to bond your account with the session keys: $rotate_keys"
}

function chainLaunchGenesis()
{
    verbose INFO "Check <chain-launch.config> and <chain-identity-file>" h
    if [ -z $1 ] || [ -z $2 ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Can't find chain-launch.config!"
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
        verbose ERROR "Please give right chain-launch.config!"
        exit 1
    fi

    if [ x"$external_rpc_ws" = x"true" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "The rpc and ws of genesis node can not be external"
        exit 1
    fi

    verbose INFO " SUCCESS" t

    chain_start_stcript="$crust_chain_main_install_dir/bin/crust --base-path $base_path --chain /opt/crust/crust-client/etc/crust_chain_spec_raw.json --port $port --ws-port $ws_port --rpc-port $rpc_port --validator --name $name"  
    if [ ! -z $bootnodes ]; then
        verbose INFO "Add bootnodes($bootnodes)" h
        chain_start_stcript="$chain_start_stcript --bootnodes=$bootnodes"
        verbose INFO " SUCCESS" t
    else
        verbose WARN "No bootnodes in chain configuration, you must be the frist genesis node."
    fi

    if [ ! -z $node_key ]; then
        verbose INFO "Add node key($node_key)" h
        chain_start_stcript="$chain_start_stcript --node-key=$node_key"
        verbose INFO " SUCCESS" t
    fi
    
    verbose INFO "Try to kill old crust chain with same <chain-launch.json>" h
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
    verbose INFO "Generate temp log file $rand_log_file for crust chain node without babe and grandpa key" h
    touch $rand_log_file
    verbose INFO " SUCCESS" t
    
    verbose INFO "Start up crust chain node without babe and grandpa key" h
    nohup $chain_start_stcript &>$rand_log_file &
    verbose INFO " SUCCESS" t

    verbose INFO "Please wait 20s for crust chain node starts completely..." n
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

    verbose INFO "Send im_online key to your chain" h
    send_im_online_key $rpc_port $public_key_sr25519 $secret_phrase 
    verbose INFO " SUCCESS" t

    verbose INFO "Send authority_discovery key to your chain" h
    send_authority_discovery_key $rpc_port $public_key_sr25519 $secret_phrase 
    verbose INFO " SUCCESS" t

    verbose INFO "Try to kill old crust chain with same <chain-launch.json> again" h
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

    verbose WARN "You need to open the port($port) in your device to make external nodes to discover your node."
    sleep 1

    if [ -z "$3" ]; then
        verbose INFO "launch crust chain(genesis node) with $1 configurations\n"
        eval $chain_start_stcript
    else
        nohup $chain_start_stcript &>$3 &
        sleep 1
        chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
        mv $3 $3.$chain_pid
        verbose INFO "launch crust chain(genesis node) with $1 configurations in backend (pid is $chain_pid), log information will be saved in $3.$chain_pid\n"
    fi
}

chainLaunchNormal()
{
    # Check configurations
    verbose INFO "Check <chain-launch.config>" h
    if [ -z $1 ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Can't find chain-launch.config!"
        exit 1
    fi

    source $1
    if [ x"$base_path" = x"" ] || [ x"$port" = x"" ] || [ x"$ws_port" = x"" ] || [ x"$rpc_port" = x"" ] || [ x"$name" = x"" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Please give right chain-launch.config!"
        exit 1
    fi
    
    verbose INFO " SUCCESS" t

    # Get chain start stcript
    chain_start_stcript="$crust_chain_main_install_dir/bin/crust --base-path $base_path --chain /opt/crust/crust-client/etc/crust_chain_spec_raw.json --pruning=archive --port $port --ws-port $ws_port --rpc-port $rpc_port --name $name"
    if [ ! -z $bootnodes ]; then
        verbose INFO "Add bootnodes($bootnodes)" h
        chain_start_stcript="$chain_start_stcript --bootnodes=$bootnodes"
        verbose INFO " SUCCESS" t
    else
        verbose ERROR "Please fill bootnodes in chain configuration!"
        exit 1
    fi

    # Kill old chain
    verbose INFO "Try to kill old crust chain with same <chain-launch.json>" h
    crust_chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
    if [ x"$crust_chain_pid" != x"" ]; then
        kill -9 $crust_chain_pid &>/dev/null
        if [ $? -ne 0 ]; then
            # If failed by using current user, kill it using root
            sudo "kill -9 $crust_chain_pid" &>/dev/null
        fi
    fi
    verbose INFO " SUCCESS" t

    # Add external rpc and ws flag
    if [ x"$external_rpc_ws" = x"true" ]; then
        chain_start_stcript="$chain_start_stcript --ws-external --rpc-external --rpc-cors all"
        verbose WARN "Rpc($rpc_port) and ws($ws_port) will be external, you need open those ports in your device to exposing ports to the external network."
    fi

    # Run chain
    sleep 1
    if [ -z "$2" ]; then
        verbose INFO "Launch crust chain(normal node) with $1 configurations\n"
        eval $chain_start_stcript
    else
        nohup $chain_start_stcript &>$2 &
        sleep 1
        chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
        mv $2 $2.$chain_pid
        verbose INFO "Launch crust chain(normal node) with $1 configurations in backend (pid is $chain_pid), log information will be saved in $2.$chain_pid\n"
    fi
}

chainLaunchValidator()
{
    # Check configurations
    verbose INFO "Check <chain-launch.config>" h
    if [ -z $1 ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Can't find chain-launch.config!"
        exit 1
    fi

    source $1
    if [ x"$base_path" = x"" ] || [ x"$port" = x"" ] || [ x"$ws_port" = x"" ] || [ x"$rpc_port" = x"" ] || [ x"$name" = x"" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Please give right chain-launch.config!"
        exit 1
    fi

    if [ x"$external_rpc_ws" = x"true" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "The rpc and ws of validator node can not be external"
        exit 1
    fi
    
    verbose INFO " SUCCESS" t

    # Get chain start stcript
    chain_start_stcript="$crust_chain_main_install_dir/bin/crust --base-path $base_path --chain /opt/crust/crust-client/etc/crust_chain_spec_raw.json --pruning=archive --validator --port $port --ws-port $ws_port --rpc-port $rpc_port --name $name" 
    if [ ! -z $bootnodes ]; then
        verbose INFO "Add bootnodes($bootnodes)" h
        chain_start_stcript="$chain_start_stcript --bootnodes=$bootnodes"
        verbose INFO " SUCCESS" t
    else
        verbose ERROR "Please fill bootnodes in chain configuration!"
        exit 1
    fi

    # Kill old chain
    verbose INFO "Try to kill old crust chain with same <chain-launch.json>" h
    crust_chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
    if [ x"$crust_chain_pid" != x"" ]; then
        kill -9 $crust_chain_pid &>/dev/null
        if [ $? -ne 0 ]; then
            sudo "kill -9 $crust_chain_pid" &>/dev/null
        fi
    fi
    verbose INFO " SUCCESS" t

    # Get rotate_keys
    get_rotate_keys $base_path $rpc_port $name $chain_start_stcript
    trap '{ echo "\nHey, you pressed Ctrl-C.  Time to quit. Please remember the node session keys: "$(cat $base_path/chains/rotate_keys.json)" ; exit 1; }' INT

    # Run chain
    sleep 1
    if [ -z "$2" ]; then
        verbose INFO "Launch crust chain(validator node) with $1 configurations\n"
        eval $chain_start_stcript
    else
        nohup $chain_start_stcript &>$2 &
        sleep 1
        chain_pid=$(ps -ef | grep "$chain_start_stcript" | grep -v grep | awk '{print $2}')
        mv $2 $2.$chain_pid
        verbose INFO "Launch crust chain(validator node) with $1 configurations in backend (pid is $chain_pid), log information will be saved in $2.$chain_pid\n"
    fi
}

ipfsLaunch()
{
    # Check <ipfs-launch.json>
    verbose INFO "Check <ipfs-launch.json>" h
    if [ x"$1" = x"" ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Can't find ipfs-launch.json!"
        exit 1
    fi
    source $1
    verbose INFO " SUCCESS" t

    # Check base_path
    export IPFS_PATH=$base_path

    if [ -d "$IPFS_PATH" ]; then
        verbose INFO "IPFS has been initialized." n
    else
        verbose INFO "Set swarm key ..." h
        mkdir -p $IPFS_PATH
        cp $swarm_key $IPFS_PATH
        checkRes $? "return"

        verbose INFO "Init ipfs..." h
        $ipfs_bin init
        checkRes $? "return"

        verbose INFO "Remove public bootstrap..." h
        $ipfs_bin bootstrap rm --all &>/dev/null
        checkRes $? "return"

        if [ -z "$master_address" ]; then
            verbose INFO "This node is master node" n
        else
            verbose INFO "This node is slave, master node is '[$master_address]'' ..." n
            $ipfs_bin bootstrap add $master_address &>/dev/null
            checkRes $? "return"
        fi

        verbose INFO "Set swarm address ..." h
        $ipfs_bin config Addresses.Swarm --json "[\"/ip4/0.0.0.0/tcp/$swarm_port\", \"/ip6/::/tcp/$swarm_port\"]" &>/dev/null
        checkRes $? "return"
    
        verbose INFO "Set api address ..." h
        $ipfs_bin config Addresses.API /ip4/0.0.0.0/tcp/$api_port &>/dev/null
        checkRes $? "return"

        verbose INFO "Set gateway address ..." h
        $ipfs_bin config Addresses.Gateway /ip4/127.0.0.1/tcp/$gateway_port &>/dev/null
        checkRes $? "return"
    
        verbose INFO "Remove all useless data ..." h
        $ipfs_bin pin rm $($ipfs_bin pin ls -q --type recursive) &>/dev/null
        $ipfs_bin repo gc &>/dev/null
        checkRes $? "return"
    fi

    cmd_run="$ipfs_bin daemon"

    if [ -z "$2" ]; then
        verbose INFO "Launch ipfs, if ipfs launch failed, please check the port usage, old ipfs may be running.\n"
        eval $cmd_run
    else
        nohup $cmd_run &>$2 &
        ipfs_pid=$(ps -ef | grep "$cmd_run" | grep -v grep | awk '{print $2}')
        mv $2 $2.$ipfs_pid
        verbose INFO "Launch ipfs in backend (pid is $ipfs_pid), log information will be saved in $2.$ipfs_pid . If ipfs launch failed, please check the port usage, old ipfs may be running.\n"
    fi
}

apiLaunch()
{
    verbose INFO "Check <api-launch.json>" h
    if [ x"$1" = x"" ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Can't find api-launch.json!"
        exit 1
    fi
    source $1
    verbose INFO " SUCCESS" t

    cmd_run="node $crust_api_main_install_dir/node_modules/.bin/ts-node $crust_api_main_install_dir/src/index.ts $crust_api_port $crust_chain_endpoint"
    if [ -z "$2" ]; then
        verbose INFO "Launch crust API with $1 configurations\n"
        $cmd_run
    else
        nohup $cmd_run &>$2 &
        api_pid=$(ps -ef | grep "$cmd_run" | grep -v grep | awk '{print $2}')
        mv $2 $2.$api_pid
        verbose INFO "Launch crust api with $1 configurations in backend (pid is $api_pid), log information will be saved in $2.$api_pid\n"
    fi
}

teeLaunch()
{
    verbose INFO "Check <tee-launch.json>" h
    if [ x"$1" = x"" ]; then
        help
        exit 1
    fi

    if [ ! -f "$1" ]; then
        verbose ERROR " Failed" t
        verbose ERROR "Can't find tee-launch.json!"
        exit 1
    fi
    verbose INFO " SUCCESS" t

    tee_config=$(cat $1)
    api_base_url=$(getJsonValuesByAwk "$tee_config" "api_base_url" "null")
    validator_api_base_url=$(getJsonValuesByAwk "$tee_config" "validator_api_base_url" "null")
    if [ $api_base_url = $validator_api_base_url ]; then
         verbose WARN "TEE verifier address is the same as yourself, please confirm that you are one of genesis nodes\n"
    fi

    cmd_run="$crust_tee_main_install_dir/bin/crust-tee -c $1"
    if [ -z "$2" ]; then
        verbose INFO "Launch crust TEE with $1 configurations\n"
        eval $cmd_run
    else
        nohup $cmd_run &>$2 &
        tee_pid=$(ps -ef | grep "$cmd_run" | grep -v grep | awk '{print $2}')
        mv $2 $2.$tee_pid
        verbose INFO "Launch tee with $1 configurations in backend (pid is $tee_pid), log information will be saved in $2.$tee_pid\n"
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
        chain-launch-genesis)
            cmd_run="chainLaunchGenesis $2 $3"
            if [ -z $2 ] && [ -z $3 ]; then
                shift 1
            elif [ -z $3 ]; then
                shift 2
            else
                shift 3
            fi
            shift 3
            ;;
        chain-launch-normal)
            cmd_run="chainLaunchNormal $2"
            if [ -z $2 ]; then
                shift 1
            else
                shift 2
            fi
            ;;
        chain-launch-validator)
            cmd_run="chainLaunchValidator $2"
            if [ -z $2 ]; then
                shift 1
            else
                shift 2
            fi
            ;;
        tee-launch)
            cmd_run="teeLaunch $2"
            if [ -z $2 ]; then
                shift 1
            else
                shift 2
            fi
            ;;
        api-launch)
            cmd_run="apiLaunch $2"
            if [ -z $2 ]; then
                shift 1
            else
                shift 2
            fi
            ;;
        ipfs-launch)
            cmd_run="ipfsLaunch $2"
            if [ -z $2 ]; then
                shift 1
            else
                shift 2
            fi
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
