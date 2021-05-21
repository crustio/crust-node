#!/bin/bash

source /opt/crust/crust-node/scripts/utils.sh

version()
{
    printf "Node type: ${node_type}\n"
    printf "Node version: ${node_version}\n"
    inner_sworker_version
    inner_docker_version
}

inner_sworker_version()
{
	local config_file=$builddir/sworker/sworker_config.json
	if [ x"$config_file" = x"" ]; then
		return
	fi

	sworker_base_url=`cat $config_file | jq .base_url`

	if [ x"$sworker_base_url" = x"" ]; then
		return
	fi

	sworker_base_url=`echo "$sworker_base_url" | sed -e 's/^"//' -e 's/"$//'`

    local id_info=`curl --max-time 30 $sworker_base_url/enclave/id_info 2>/dev/null`
	if [ x"$id_info" = x"" ]; then
		return
	fi
    printf "SWorker version:\n${id_info}\n"
}

inner_docker_version()
{
    local chain_image=(`docker images | grep '^\b'crustio/crust'\b ' | grep 'latest'`)
    chain_image=${chain_image[2]}

    local sworker_image=(`docker images | grep '^\b'crustio/crust-sworker'\b ' | grep 'latest'`)
    sworker_image=${sworker_image[2]}

    local cgen_image=(`docker images | grep '^\b'crustio/config-generator'\b ' | grep 'latest'`)
    cgen_image=${cgen_image[2]}

    local ipfs_image=(`docker images | grep '^\b'ipfs/go-ipfs'\b ' | grep 'latest'`)
    ipfs_image=${ipfs_image[2]}

    local api_image=(`docker images | grep '^\b'crustio/crust-api'\b ' | grep 'latest'`)
    api_image=${api_image[2]}

    local smanager_image=(`docker images | grep '^\b'crustio/crust-smanager'\b ' | grep 'latest'`)
    smanager_image=${smanager_image[2]}

    printf "Docker images:\n"
    printf "  Chain: ${chain_image}\n"
    printf "  SWorker: ${sworker_image}\n"
    printf "  C-gen: ${cgen_image}\n"
    printf "  IPFS: ${ipfs_image}\n"
    printf "  API: ${api_image}\n"
    printf "  Smanager: ${smanager_image}\n"
}