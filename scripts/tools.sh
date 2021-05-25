#!/bin/bash

source /opt/crust/crust-node/scripts/utils.sh

tools_help()
{
cat << EOF
Crust tools usage:
    help                                                       show help information
    space-info                                                 show information about data folders
    rotate-keys                                                generate session key of chain node
    upgrade-image {chain|api|smanager|ipfs|c-gen|sworker}      upgrade one docker image
    sworker-ab-upgrade {code}                                  sworker AB upgrade
    workload                                                   show workload information
    file-info {cid}                                            show all files information or one file details
    delete-file {cid}                                          delete one file
    set-srd-ratio {ratio}                                      set SRD raito, default is 99%, range is 0% - 99%, for example 'set-srd-ratio 75'
    change-srd {number}                                        change sworker's srd capacity(GB), for example: 'change-srd 100', 'change-srd -50'
    ipfs {...}                                                 ipfs command, for example 'ipfs pin ls', 'ipfs swarm peers'
EOF
}

space_info()
{
    local data_folder_info=(`df -h /opt/crust/data | sed -n '2p'`)
cat << EOF
>>>>>> Base data folder <<<<<<
Path: /opt/crust/data
File system: ${data_folder_info[0]}
Total space: ${data_folder_info[1]}
Used space: ${data_folder_info[2]}
Avail space: ${data_folder_info[3]}
EOF

    for i in $(seq 1 128); do
        local disk_folder_info=(`df -h /opt/crust/data/disks/${i} | sed -n '2p'`)
        if [ x"${disk_folder_info[0]}" != x"${data_folder_info[0]}" ]; then
            printf "\n>>>>>> Storage folder ${i} <<<<<<\n"
            printf "Path: /opt/crust/data/disks/${i}\n"
            printf "File system: ${disk_folder_info[0]}\n"
            printf "Total space: ${disk_folder_info[1]}\n"
            printf "Used space: ${disk_folder_info[2]}\n"
            printf "Avail space: ${disk_folder_info[3]}\n"
        fi
    done

cat << EOF

PS:
1. Base data folder is used to store chain and db, 2TB SSD is recommended
2. Please mount the hard disk to storage folders, paths is from: /opt/crust/data/disks/1 ~ /opt/crust/data/disks/128
3. SRD will not use all the space, it will reserve 50G of space
EOF
}

rotate_keys()
{
    check_docker_status crust
    if [ $? -ne 0 ]; then
        log_info "Service chain is not started or exited now"
        return 0
    fi

    local res=`curl -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "author_rotateKeys", "params":[]}' http://localhost:19933 2>/dev/null`
    session_key=`echo $res | jq .result`
    if [ x"$session_key" = x"" ]; then
        log_err "Generate session key failed"
        return 1
    fi
    echo $session_key
}

change_srd()
{
    if [ x"$1" == x"" ] || [[ ! $1 =~ ^[1-9][0-9]*$|^[-][1-9][0-9]*$|^0$ ]]; then 
        log_err "The input of srd change must be integer number"
        tools_help
        return 1
    fi

    local a_or_b=`cat $basedir/etc/sWorker.ab`
    check_docker_status crust-sworker-$a_or_b
    if [ $? -ne 0 ]; then
        log_info "Service crust sworker is not started or exited now"
        return 0
    fi

    if [ ! -f "$builddir/sworker/sworker_config.json" ]; then
        log_err "No sworker configuration file"
        return 1
    fi

    local base_url=`cat $builddir/sworker/sworker_config.json | jq .base_url`
    base_url=${base_url%?}
    base_url=${base_url:1}

    curl -XPOST ''$base_url'/srd/change' -H 'backup: '$backup'' --data-raw '{"change" : '$1'}'
}

set_srd_ratio()
{
    if [ x"$1" == x"" ] || [[ ! $1 =~ ^[1-9][0-9]*$|^[-][1-9][0-9]*$|^0$ ]]; then 
        log_err "The input of set srd ratio must be integer number"
        tools_help
        return 1
    fi

    if [ $1 -lt 0 ] || [ $1 -gt 99 ]; then
        log_err "The range of set srd ratio is 0 ~ 99"
        tools_help
        return 1
    fi

    local a_or_b=`cat $basedir/etc/sWorker.ab`
    check_docker_status crust-sworker-$a_or_b
    if [ $? -ne 0 ]; then
        log_info "Service crust sworker is not started or exited now"
        return 0
    fi

    if [ ! -f "$builddir/sworker/sworker_config.json" ]; then
        log_err "No sworker configuration file"
        return 1
    fi

    local base_url=`cat $builddir/sworker/sworker_config.json | jq .base_url`
    base_url=${base_url%?}
    base_url=${base_url:1}

    curl -XPOST ''$base_url'/srd/ratio' -H 'backup: '$backup'' --data-raw '{"ratio" : '$1'}'
}

workload()
{
    local a_or_b=`cat $basedir/etc/sWorker.ab`
    check_docker_status crust-sworker-$a_or_b
    if [ $? -ne 0 ]; then
        log_info "Service crust sworker is not started or exited now"
        return 0
    fi

    local base_url=`cat $builddir/sworker/sworker_config.json | jq .base_url`
    base_url=${base_url%?}
    base_url=${base_url:1}

    curl $base_url/workload
}

file_info()
{
    local a_or_b=`cat $basedir/etc/sWorker.ab`
    check_docker_status crust-sworker-$a_or_b
    if [ $? -ne 0 ]; then
        log_info "Service crust sworker is not started or exited now"
        return 0
    fi

    local base_url=`cat $builddir/sworker/sworker_config.json | jq .base_url`
    base_url=${base_url%?}
    base_url=${base_url:1}

    if [ x"$1" == x"" ]; then
        curl $base_url/file/info_all --output sworker_file_info_all.json
    else
        curl --request POST ''$base_url'/file/info' --header 'Content-Type: application/json' --data-raw '{"cid":"'$1'"}'
    fi
}

delete_file()
{
    local a_or_b=`cat $basedir/etc/sWorker.ab`
    check_docker_status crust-sworker-$a_or_b
    if [ $? -ne 0 ]; then
        log_info "Service crust sworker is not started or exited now"
        return 0
    fi

    local base_url=`cat $builddir/sworker/sworker_config.json | jq .base_url`
    base_url=${base_url%?}
    base_url=${base_url:1}
    curl --request POST ''$base_url'/storage/delete' --header 'Content-Type: application/json' --data-raw '{"cid":"'$1'"}'
}

upgrade_image()
{
    if [ x"$1" == x"chain" ]; then
        upgrade_docker_image crust $2
        if [ $? -ne 0 ]; then
            return 1
        fi
    elif [ x"$1" == x"api" ]; then
        upgrade_docker_image crust-api $2
        if [ $? -ne 0 ]; then
            return 1
        fi
    elif [ x"$1" == x"smanager" ]; then
        upgrade_docker_image crust-smanager $2
        if [ $? -ne 0 ]; then
            return 1
        fi
    elif [ x"$1" == x"ipfs" ]; then
        upgrade_docker_image go-ipfs $2
        if [ $? -ne 0 ]; then
            return 1
        fi
    elif [ x"$1" == x"c-gen" ]; then
        upgrade_docker_image config-generator $2
        if [ $? -ne 0 ]; then
            return 1
        fi
    elif [ x"$1" == x"sworker" ]; then
        upgrade_docker_image crust-sworker $2
        if [ $? -ne 0 ]; then
            return 1
        fi
    else
        tools_help
    fi
}

ipfs_cmd()
{
    check_docker_status ipfs
    if [ $? -ne 0 ]; then
        log_info "Service ipfs is not started or exited now"
        return 0
    fi
    docker exec -i ipfs ipfs $@
}

sworker_ab_upgrade()
{
    # Check input 
    if [ x"$1" == x"" ]; then
        log_err "Please give new sWorker code."
        tools_help
        return 1
    fi
    local code=$1

    # Check sworker
    local a_or_b=`cat $basedir/etc/sWorker.ab`
    check_docker_status crust-sworker-$a_or_b
    if [ $? -ne 0 ]; then
        log_err "Service crust sWorker is not started or exited now"
        return 1
    fi

    log_info "Start sworker A/B upgragde...."

    # Get configurations
    local config_file=$builddir/sworker/sworker_config.json
    if [ x"$config_file" = x"" ]; then
        log_err "please give right config file"
        return 1
    fi

    api_base_url=`cat $config_file | jq .chain.base_url`
    sworker_base_url=`cat $config_file | jq .base_url`

    if [ x"$api_base_url" = x"" ] || [ x"$sworker_base_url" = x"" ]; then
        log_err "please give right config file"
        return 1
    fi

    api_base_url=`echo "$api_base_url" | sed -e 's/^"//' -e 's/"$//'`
    sworker_base_url=`echo "$sworker_base_url" | sed -e 's/^"//' -e 's/"$//'`

    log_info "Read configurations success."

    if [ x"$2" != x"no-chain" ]; then
        # Check chain
        while :
        do
            system_health=`curl --max-time 30 $api_base_url/system/health 2>/dev/null`
            if [ x"$system_health" = x"" ]; then
                log_err "Service crust chain or api is not started or exited now"
                return 1
            fi

            is_syncing=`echo $system_health | jq .isSyncing`
            if [ x"$is_syncing" = x"" ]; then
                log_err "Service crust api dose not connet to crust chain"
                return 1
            fi

            if [ x"$is_syncing" = x"true" ]; then
                printf "\n"
                for i in $(seq 1 60); do
                    printf "Crust chain is syncing, please wait 60s, now is %s\r" "${i}s"
                    sleep 1
                done
                continue
            fi
            break
        done
    fi

    # Get code from sworker
    local id_info=`curl --max-time 30 $sworker_base_url/enclave/id_info 2>/dev/null`
    if [ x"$id_info" = x"" ]; then
        log_err "Please check sworker logs to find more information"
        return 1
    fi

    local mrenclave=`echo $id_info | jq .mrenclave`
    if [ x"$mrenclave" = x"" ] || [ ! ${#mrenclave} -eq 66 ]; then
        log_err "Please check sworker logs to find more information"
        return 1
    fi
    mrenclave=`echo ${mrenclave: 1: 64}`
    log_info "sWorker self code: $mrenclave"

    if [ x"$mrenclave" == x"$code" ]; then
        log_success "sWorker is already latest"
        while :
        do
            check_docker_status crust-sworker-a
            local resa=$?
            check_docker_status crust-sworker-b
            local resb=$?
            if [ $resa -eq 0 ] && [ $resb -eq 0 ] ; then
                sleep 10
                continue
            fi
            break
        done

        check_docker_status crust-sworker-a
        if [ $? -eq 0 ]; then
            local aimage=(`docker ps -a | grep 'crust-sworker-a'`)
            aimage=${aimage[1]}
            if [ x"$aimage" != x"crustio/crust-sworker:latest" ]; then
                docker tag $aimage crustio/crust-sworker:latest
            fi
        fi

        check_docker_status crust-sworker-b
        if [ $? -eq 0 ]; then
            local bimage=(`docker ps -a | grep 'crust-sworker-b'`)
            bimage=${bimage[1]}
            if [ x"$bimage" != x"crustio/crust-sworker:latest" ]; then
                docker tag $bimage crustio/crust-sworker:latest
            fi
        fi        
        return 0
    fi

    # Upgrade sworker images
    local old_image=(`docker images | grep '^\b'crustio/crust-sworker'\b ' | grep 'latest'`)
    old_image=${old_image[2]}

    local region=`cat $basedir/etc/region.conf`
    local docker_org="crustio"
    if [ x"$region" == x"cn" ]; then
       docker_org=$aliyun_address/$docker_org
    fi

    local res=0
    docker pull $docker_org/crust-sworker:$code
    res=$(($?|$res))
    docker tag $docker_org/crust-sworker:$code crustio/crust-sworker:latest

    if [ $res -ne 0 ]; then
        log_err "Download sworker docker image failed"
        return 1
    fi

    local new_image=(`docker images | grep '^\b'crustio/crust-sworker'\b ' | grep 'latest'`)
    new_image=${new_image[2]}
    if [ x"$old_image" = x"$new_image" ]; then
        log_info "The current sworker docker image is already the latest"
        return 1
    fi

    # Start A/B
    if [ x"$a_or_b" = x"a" ]; then
        a_or_b='b'
    else
        a_or_b='a'
    fi

    check_docker_status crust-sworker-a
    local resa=$?
    check_docker_status crust-sworker-b
    local resb=$?
    if [ $resa -eq 0 ] && [ $resb -eq 0 ] ; then
        log_info "sWorker A/B upgrade is already in progress"
    else
        docker stop crust-sworker-$a_or_b &>/dev/null
        docker rm crust-sworker-$a_or_b &>/dev/null
        EX_SWORKER_ARGS=--upgrade docker-compose -f $composeyaml up -d crust-sworker-$a_or_b
        if [ $? -ne 0 ]; then
            log_err "Setup new sWorker failed"
            docker tag $old_image crustio/crust-sworker:latest
            return 1
        fi
    fi

    # Change back to older image
    docker tag $old_image crustio/crust-sworker:latest
    log_info "Please do not close this program and wait patiently, ."
    log_info "If you need more information, please use other terminal to execute 'sudo crust logs sworker-a' and 'sudo crust logs sworker-b'"

    # Check A/B status
    local acc=0
    while :
    do
        printf "Sworker is upgrading, please do not close this program. Wait %s\r" "${acc}s"
        ((acc++))
        sleep 1

        # Get code from sworker
        local id_info=`curl --max-time 30 $sworker_base_url/enclave/id_info 2>/dev/null`
        if [ x"$id_info" != x"" ]; then
            local mrenclave=`echo $id_info | jq .mrenclave`
            if [ x"$mrenclave" != x"" ]; then
                mrenclave=`echo ${mrenclave: 1: 64}`
                if [ x"$mrenclave" == x"$code" ]; then
                    break
                fi
            fi
        fi

        # Check upgrade sworker status
        check_docker_status crust-sworker-$a_or_b
        if [ $? -ne 0 ]; then
            printf "\n"
            log_err "Sworker update failed, please use 'sudo crust logs sworker-a' and 'sudo crust logs sworker-b' to find more details"
            return 1
        fi
    done
    
    # Set new information
    docker tag $new_image crustio/crust-sworker:latest

    if [ x"$a_or_b" = x"a" ]; then
        sed -i 's/b/a/g' $basedir/etc/sWorker.ab
    else
        sed -i 's/a/b/g' $basedir/etc/sWorker.ab
    fi

    printf "\n"
    log_success "Sworker update success, setup new sworker 'crust-sworker-$a_or_b'"
}

tools()
{
    case "$1" in
        space-info)
            space_info
            ;;
        change-srd)
            change_srd $2
            ;;
        set-srd-ratio)
            set_srd_ratio $2
            ;;
        rotate-keys)
            rotate_keys
            ;;
        workload)
            workload
            ;;
        file-info)
            file_info $2
            ;;
        delete-file)
            delete_file $2
            ;;
        upgrade-image)
            upgrade_image $2 $3
            ;;
        sworker-ab-upgrade)
            sworker_ab_upgrade $2 $3
            ;;
        ipfs)
            shift
            ipfs_cmd $@
            ;;
        *)
            tools_help
    esac
}