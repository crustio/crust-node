#!/bin/bash

# Base var
scriptdir=$(cd `dirname $0`;pwd)
basedir=$(cd $scriptdir/..;pwd)
config_path=$basedir/config/config.json
raw_configdir=$basedir/config/raw
chain_config_path=$raw_configdir/chain_config.json
api_config_path=$raw_configdir/api_config.json
tee_config_path=$raw_configdir/tee_config.json
karst_config_path=$raw_configdir/karst_config.json

. $scriptdir/utils.sh

function generateChainConfig() {
    local base_path=$(cat $1 | jq ".chain.base_path")
    local name=$(cat $1 | jq ".chain.name")
    local port=$(cat $1 | jq ".chain.port")
    local rpc_port=$(cat $1 | jq ".chain.rpc_port")
    local ws_port=$(cat $1 | jq ".chain.ws_port")

local config_content='
{
    "base_path": '$base_path',
    "name": '$name',
    "port": '$port',
    "rpc_port": '$rpc_port',
    "ws_port": '$ws_port'
}
'
echo $config_content | jq . > $chain_config_path
}

function generateApiConfig() {
    local api_port=$(cat $1 | jq ".api.port")
    local chain_ws_port=$(cat $1 | jq ".chain.ws_port")

local config_content='
{
    "port": '$api_port',
    "chain_ws_url": "ws://127.0.0.1:'$chain_ws_port'/"
}
'
echo $config_content | jq . > $api_config_path
}

function generateTeeConfig() {
    local address=$(cat $1 | jq ".identity.address")
    local account_id=$(cat $1 | jq ".identity.account_id")
    local password=$(cat $1 | jq ".identity.password")
    local backup=$(cat $1 | jq ".identity.backup")
    local api_port=$(cat $1 | jq ".api.port")
    local tee_port=$(cat $1 | jq ".tee.port")
    local tee_base_path=$(cat $1 | jq ".tee.base_path")
    local tee_srd_paths=$(cat $1 | jq ".tee.srd_paths")
    local tee_srd_capacity=$(cat $1 | jq ".tee.srd_capacity")
    local karst_port=$(cat $1 | jq ".karst.port")
local config_content='
{
    "base_path" : '$tee_base_path',
    "base_url": "http://0.0.0.0:'$tee_port'/api/v0",
    "srd_paths" : '$tee_srd_paths',
    "srd_capacity" : '$tee_srd_capacity', 
    
    "karst_url":  "ws://127.0.0.1:'$karst_port'/api/v0/node/data",
    "chain": {
        "base_url":"http://127.0.0.1:'$api_port'/api/v1",
        "address": '$address',
        "account_id": '$account_id',
        "password": '$password',
        "backup": '$backup'
    }
}
'
echo $config_content | jq . > $tee_config_path
}

function generateKarstConfig() {
    local address=$(cat $1 | jq ".identity.address")
    local password=$(cat $1 | jq ".identity.password")
    local backup=$(cat $1 | jq ".identity.backup")
    local api_port=$(cat $1 | jq ".api.port")
    local tee_port=$(cat $1 | jq ".tee.port")
    local karst_port=$(cat $1 | jq ".karst.port")
    local krast_tracker_addrs=$(cat $1 | jq ".karst.tracker_addrs")
    local krast_base_path=$(cat $1 | jq ".karst.base_path")
local config_content='
{
    "base_path": '$krast_base_path',
    "base_url": "0.0.0.0:'$karst_port'",
    "crust": {
        "address": '$address',
        "backup": '$backup',
        "base_url": "127.0.0.1:'$api_port'/api/v1",
        "password": '$password'
    },
    "fastdfs": {
        "max_conns": 100,
        "tracker_addrs": '$krast_tracker_addrs'
    },
    "log_level": "debug",
    "tee_base_url": "127.0.0.1:'$tee_port'/api/v0"
}
'
echo $config_content | jq . > $karst_config_path
}

# Install denpendencies

verbose INFO "Install jq ... " h
res=0
apt-get install jq &>/dev/null
res=$(($?|$res))
checkRes $res

# Check json legitimacy
cat $config_path | jq .

# Remove old raw configurations
verbose INFO "Remove old raw configurations ... " h
rm -rf $raw_configdir &>/dev/null
res=$(($?|$res))
checkRes $res
mkdir -p $raw_configdir

# Build chain configuration
verbose INFO "Generate chain configuration ... " h
generateChainConfig $config_path
res=$(($?|$res))
checkRes $res

# Build api configuration
verbose INFO "Generate api configuration ... " h
generateApiConfig $config_path
res=$(($?|$res))
checkRes $res

# Build tee configuration
verbose INFO "Generate tee configuration ... " h
generateTeeConfig $config_path
res=$(($?|$res))
checkRes $res

# Build karst configuration
verbose INFO "Generate karst configuration ... " h
generateKarstConfig $config_path
res=$(($?|$res))
checkRes $res
