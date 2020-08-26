#!/bin/bash

scriptdir=$(cd `dirname $0`;pwd)
basedir=$(cd $scriptdir/..;pwd)
config_file=$basedir/build/sworker/sworker_config.json
compose_file=$basedir/build/docker-compose.yaml
builddir=$basedir/build

function upgrade_sworker()
{
    echo "Start upgrade...."
    docker pull crustio/crust-sworker:latest
    if [ $? -ne 0 ]; then
        echo "download docker image failed"
        return -1
    fi

    time_now=`date +%s%3N`
    upgrade_builddir=$builddir$time_now
    cp -r $builddir $upgrade_builddir
    EX_SWORKER_ARGS=--upgrade docker-compose -f $upgrade_builddir/docker-compose.yaml -d crust-sworker
    if [ $? -ne 0 ]; then
        echo "setup new sworker failed"
        return -1
    fi

    echo "setup new sworker in $upgrade_builddir"
}

if [ x"$config_file" = x"" ]; then
    echo "please give right config file"
    exit -1
fi

api_base_url=`cat $config_file | jq .chain.base_url`
sworker_base_url=`cat $config_file | jq .base_url`

if [ x"$api_base_url" = x"" ] || [ x"$sworker_base_url" = x"" ]; then
    echo "please give right config file"
    exit -1
fi

api_base_url=`echo "$api_base_url" | sed -e 's/^"//' -e 's/"$//'`
sworker_base_url=`echo "$sworker_base_url" | sed -e 's/^"//' -e 's/"$//'`

sleep 30
while :
do

system_health=`curl $api_base_url/system/health 2>/dev/null`
if [ x"$system_health" = x"" ]; then
    echo "please run crust chain and api"
    sleep 10
    continue
fi

is_syncing=`echo $system_health | jq .isSyncing`
if [ x"$is_syncing" = x"" ]; then
    echo "crust api dose not connet to crust chain"
    sleep 10
    continue
fi

if [ x"$is_syncing" = x"true" ]; then
    echo "crust chain is syncing"
    sleep 10
    continue
fi

code=`curl $api_base_url/tee/code 2>/dev/null`
if [ x"$code" = x"" ]; then
    echo "please run chain and api"
    sleep 10
    continue
fi
code=`echo ${code: 3: 64}`
echo "sWorker code on chain: $code"

id_info=`curl $sworker_base_url/enclave/id_info 2>/dev/null`
if [ x"$id_info" = x"" ]; then
    echo "please run sworker"
    sleep 10
    continue
fi

mrenclave=`echo $id_info | jq .mrenclave`
if [ x"$mrenclave" = x"" ]; then
    echo "waiting sworker ready"
    sleep 10
    continue
fi
mrenclave=`echo ${mrenclave: 1: 64}`

echo "sWorker self code: $mrenclave"

if [ x"$mrenclave" != x"$code" ]; then
    upgrade_swoker
fi

sleep 10
done
