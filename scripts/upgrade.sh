#!/bin/bash

scriptdir=$(cd `dirname $0`;pwd)
basedir=$(cd $scriptdir/..;pwd)
config_file=$basedir/build/sworker/sworker_config.json
builddir=$basedir/build

function upgrade_sworker()
{
    echo "Upgrade...."
    old_image=(`docker images | grep '^\bcrustio/crust-sworker\b ' | grep 'latest'`)
    old_image=${old_image[3]}

    region=`cat $basedir/etc/region.conf`
    res=0
    if [ x"$region" == x"cn" ]; then
        local aliyun_address=registry.cn-hangzhou.aliyuncs.com
        docker pull $aliyun_address/crustio/crust-sworker
        res=$(($?|$res))
        docker tag $aliyun_address/crustio/crust-sworker crustio/crust-sworker
    else
        docker pull crustio/crust-sworker
    fi

    if [ $res -ne 0 ]; then
        echo "download docker image failed"
        return 1
    fi

    new_image=(`docker images | grep '^\bcrustio/crust-sworker\b ' | grep 'latest'`)
    new_image=${new_image[3]}
    if [ x"$old_image" = x"$new_image" ]; then
        return 0
    fi

    a_or_b=`cat $basedir/etc/sWorker.ab`

    docker-compose -f $builddir/docker-compose.yaml stop crust-sworker-$a_or_b &>/dev/null
    docker-compose -f $builddir/docker-compose.yaml rm crust-sworker-$a_or_b &>/dev/null
    EX_SWORKER_ARGS=--upgrade docker-compose -f $builddir/docker-compose.yaml up -d crust-sworker-$a_or_b
    if [ $? -ne 0 ]; then
        echo "setup new sworker failed"
        return 1
    fi
    
    if [ x"$a_or_b" = x"a" ]; then
        a_or_b='b'
        sed -i 's/a/b/g' $basedir/etc/sWorker.ab
    else
        a_or_b='a'
        sed -i 's/b/a/g' $basedir/etc/sWorker.ab
    fi

    echo "setup new sworker 'crust-sworker-$a_or_b'"
}

if [ x"$config_file" = x"" ]; then
    echo "please give right config file"
    exit 1
fi

api_base_url=`cat $config_file | jq .chain.base_url`
sworker_base_url=`cat $config_file | jq .base_url`

if [ x"$api_base_url" = x"" ] || [ x"$sworker_base_url" = x"" ]; then
    echo "please give right config file"
    exit 1
fi

api_base_url=`echo "$api_base_url" | sed -e 's/^"//' -e 's/"$//'`
sworker_base_url=`echo "$sworker_base_url" | sed -e 's/^"//' -e 's/"$//'`

echo "Wait 60s for sworker to start"
sleep 60
while :
do

system_health=`curl $api_base_url/system/health 2>/dev/null`
if [ x"$system_health" = x"" ]; then
    echo "please run crust chain and api"
    sleep 60
    continue
fi

is_syncing=`echo $system_health | jq .isSyncing`
if [ x"$is_syncing" = x"" ]; then
    echo "crust api dose not connet to crust chain"
    sleep 60
    continue
fi

if [ x"$is_syncing" = x"true" ]; then
    echo "crust chain is syncing"
    sleep 60
    continue
fi

code=`curl $api_base_url/swork/code 2>/dev/null`
if [ x"$code" = x"" ]; then
    echo "please run chain and api"
    sleep 60
    continue
fi

if [[ ! "$code" =~ ^\"0x.* ]]; then
    echo "please run chain and api"
    sleep 60
    continue
fi

code=`echo ${code: 3: 64}`
echo "sWorker code on chain: $code"

id_info=`curl $sworker_base_url/enclave/id_info 2>/dev/null`
if [ x"$id_info" = x"" ]; then
    echo "please run sworker"
    sleep 60
    continue
fi

mrenclave=`echo $id_info | jq .mrenclave`
if [ x"$mrenclave" = x"" ]; then
    echo "waiting sworker ready"
    sleep 60
    continue
fi
mrenclave=`echo ${mrenclave: 1: 64}`

echo "sWorker self code: $mrenclave"

if [ x"$mrenclave" != x"$code" ] && [ ${#mrenclave} -eq ${#code} ]; then
    upgrade_sworker
fi

sleep 60
done
