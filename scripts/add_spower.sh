#!/bin/bash
function get_number_by_cid()
{
    local cid=$1
    local tail=$2
    local number=0
    for i in $(seq 1 $tail); do
        tmp=${cid:len-i:1}
        tmp=$(printf '%d' "'$tmp")
        ((number=number+tmp))
    done
    echo $number
}

function is_number()
{
    if [[ $1 =~ ^[1-9]+[0-9]*$ ]] || [ x"$1" = x"0" ]; then
        return 0
    fi
    return 1
}

function get_spower()
{
    local spower_t=$1
    local unit=${spower_t##*[0-9]}
    local size=${spower_t%%[a-zA-Z]*}
    local res=""
    if is_number $size && [ x"${unit_map[$unit]}" != x"" ]; then
        res=$((size*${unit_map[$unit]}))
    fi
    echo $res
}

function max()
{
    local x1=$1
    local x2=$2
    if ! is_number $x1; then
        x1=0
    fi
    if ! is_number $x2; then
        x2=0
    fi
    if [ $x1 -gt $x2 ]; then
        echo $x1
    else
        echo $x2
    fi
}

function min()
{
    local x1=$1
    local x2=$2
    if ! is_number $x1; then
        x1=0
    fi
    if ! is_number $x2; then
        x2=0
    fi
    if [ $x1 -lt $x2 ]; then
        echo $x1
    else
        echo $x2
    fi
}

function is_enough()
{
    if [ x"$target_spower" != x"" ]; then
        if ((spower_cur >= target_spower)); then
            return 0
        fi
    fi
    if [ x"$target_number" != x"" ]; then
        if ((number_cur >= target_number)); then
            return 0
        fi
    fi
    return 1
}

function usage()
{
    echo "Usage:"
    echo "     $0 [options]"
    echo "Options:"
    echo "     -n|--number <number>: Required, indicate add file number, cannot be set with -s"
    echo "     -s|--spower <number><unit>: Required, indicate add spower whose unit must be g/G/t/T, cannot be set with -n"
    echo "     --reset: Delete previous metadata"
    echo "     --new: Get new order first, if not set, just load old order"
    echo "     -h|--help: Display help message"
}

########## MAIN BODY ##########
basedir=$(cd `dirname $0`; pwd)
spower_dir=$basedir/spower
TMPFILE=$spower_dir/tmp
TMPFILE2=$spower_dir/tmp2
owned_cids_file=$spower_dir/owned_cids
add_files_script=$spower_dir/add_files.sh
prev_meta_file=$spower_dir/prev_meta
crust_base_url="http://localhost:12222/api/v0"
files_url="https://crust.webapi.subscan.io/api/scan/swork/member/files"
# Color
RED='\033[0;31m'
HRED='\033[1;31m'
GREEN='\033[0;32m'
HGREEN='\033[1;32m'
YELLOW='\033[0;33m'
HYELLOW='\033[1;33m'
NC='\033[0m'

declare -A unit_map
declare -A id_2_lblk

unit_map[g]=$((1024*1024*1024))
unit_map[G]=${unit_map[g]}
unit_map[t]=$((${unit_map[g]}*1024))
unit_map[T]=${unit_map[t]}

# used to indicate fetching new or old order
# 0 indicates get new order
# 1 indicates get old order
break_cond=1
RESET=false
GETNEW=false
options=$(getopt -o n:s:h --long number,spower,reset,new,help -- "$@")
[ $? -eq 0 ] || { 
    echo "ERROR: incorrect options provided"
    exit 1
}
eval set -- "$options"
while true; do
    case "$1" in
    -n|--number)
        if [ x"$target_spower" != x"" ]; then
            usage
            exit 1
        fi
        shift; # The arg is next in position args
        FILENUM=$1
        if ! is_number $FILENUM; then
            echo "ERROR: Wrong -n argument which must be number"
            usage
            exit 1
        fi
        target_number=$FILENUM
        ;;
    -s|--spower)
        if [ x"$target_number" != x"" ]; then
            usage
            exit 1
        fi
        shift; # The arg is next in position args
        SPOWER=$1
        target_spower=$(get_spower $SPOWER)
        if [ x"$target_spower" = x"" ]; then
            echo "ERROR: Wrong -s argument which should be like 11g"
            usage
            exit 1
        fi
        ;;
    --reset)
        RESET=true
        ;;
    --new)
        GETNEW=true
        ;;
    -h|--help)
        usage
        exit 1
        ;;
    --)
        shift
        break
        ;;
    ?)
        echo "ERROR: invalid option:-$1" 1>&2
        usage
        exit 1
        ;;
    esac
    shift
done
if [ x"$target_number" = x"" ] && [ x"$target_spower" = x"" ]; then
    usage
    exit 1
fi
if $RESET; then
    rm -rf $spower_dir &>/dev/null
fi
if $GETNEW; then
    break_cond=0
fi

mkdir -p $spower_dir

account=$(curl -s http://localhost:12222/api/v0/enclave/id_info | jq .account)
if [ x"$account" = x"" ]; then
    echo "ERROR: get sWorker account failed, please make sure sWorker is running!"
    exit 1
fi
### Get owner id
echo "INFO: get owner id by current account:'$account'..."
subsquid_url="https://crust.indexer.gc.subsquid.io/v4/graphql"
owner_id=$(curl -s -XPOST $subsquid_url --data-raw '{"query": "query MyQuery {\n  substrate_extrinsic(where: {signer: {_eq: \"'$account'\"}, method: {_eq: \"joinGroup\"}}, limit: 1) {\n    substrate_events(where: {method: {_eq: \"JoinGroupSuccess\"}}) {\n      data(path: \".param1.value\")\n    }\n  }\n}\n"}' | jq -r '.data.substrate_extrinsic|.[0].substrate_events|.[0].data')
if [ x"$owner_id" = x"" ] || [ ${#owner_id} -ne ${#account} ]; then
    echo "ERROR: cannot get owner account by current account:'$account', please try again"
    exit 1
fi
echo "INFO: current account's owner:'$owner_id'"
member_ids=($(curl -s -XPOST https://crust.webapi.subscan.io/api/scan/swork/group/members --data-raw '{"row": 1000, "page": 0, "group_owner": "'$owner_id'"}' | jq -r '.data.list|.[]|.account_id' | sort))
if [ ${#member_ids[@]} -le 0 ]; then
    echo "INFO: no member has been found"
    exit 0
fi
echo "INFO: get ${#member_ids[@]} members for owner"

### Get all owner files
true > $TMPFILE
true > $TMPFILE2
if [ -s "$owned_cids_file" ]; then
    cat $owned_cids_file > $TMPFILE2
else
    rm $prev_meta_file &>/dev/null
fi
trap 'rm $TMPFILE $TMPFILE2' EXIT
echo "INFO: get files from subsquid..."
member_acc=0
file_num=0
fetched_latest_blk=0
# Get previous meta
if [ -s $prev_meta_file ]; then
    for el in $(cat $prev_meta_file 2>/dev/null); do
        eval $el
    done
    echo "INFO: get previous running data"
    echo "      current group total file number:$(cat $owned_cids_file | wc -l)"
    echo "      searched newest order block:$fetch_start_blk_n"
    echo "      searched oldest order block:$fetch_start_blk_o"
    echo "      tips: if you want to reset search, add '--reset' option"
fi
for id in ${member_ids[@]}; do
    if ! echo ${member_ids[@]} | grep $id &>/dev/null; then
        rm -rf $spower_dir &>/dev/null
        true > $TMPFILE2
        unset id_2_lblk
        declare -A id_2_lblk
    fi
done
for id in ${member_ids[@]}; do
    ((member_acc++))
    printf "%s" "INFO: id:'$id' files from subscan...$member_acc/${#member_ids[@]}"
    lest_report_blk=0
    lest_order_blk=0

    # Get files by account
    cond=""
    if [ x"${id_2_lblk[$id]}" != x"" ]; then
        blk_num=${id_2_lblk[$id]}
        cond="(where:{blockNum_gt:$blk_num})"
    fi
    curl -s -XPOST -H "content-type: application/json; charset=utf-8" 'https://app.gc.subsquid.io/beta/crust/001/graphql' --data-raw '{"query": "query MyQuery {\n  accountById(id: \"'$id'\") {\n    workReports'$cond' {\n      addedFiles\n      deletedFiles\n    blockNum\n    }\n  }\n}"}'  > $TMPFILE
    if [ x"$(cat $TMPFILE | jq -r ".data.accountById.workReports|length")" = x"0" ]; then
        echo " No more files can be got from block:${id_2_lblk[$id]}"
        continue
    elif ! cat $TMPFILE | jq . &>/dev/null; then
        echo " Cannot get files from block:${id_2_lblk[$id]}, please try again"
        exit 1
    fi
    declare -A acc_map
    for el in $(cat $TMPFILE | jq -r ".data.accountById.workReports|.[]|.addedFiles|.[]|.[0]"); do
        tmp=${acc_map[$el]}
        if [ x"$tmp" = x"" ]; then
            tmp=0
        else
            ((tmp++))
        fi
        acc_map[$el]=$tmp
    done
    for el in $(cat $TMPFILE | jq -r ".data.accountById.workReports|.[]|.deletedFiles|.[]|.[0]"); do
        tmp=${acc_map[$el]}
        acc_map[$el]=$((tmp-1))
    done
    for key in ${!acc_map}; do
        if [ ${acc_map[$key]} -le 0 ]; then
            unset 'acc_map[$key]'
        fi
    done
    # Get latest block number
    blocks_arry=($(cat $TMPFILE | jq '.data.accountById.workReports|.[]|.blockNum'))
    lest_report_blk=$(max $lest_report_blk ${blocks_arry[len-1]})
    # Get valid file cid
    j=0
    exist=false
    for el in $(cat $TMPFILE | jq -r ".data.accountById.workReports|.[]|.addedFiles|.[]|.[0,2]"); do
        if ((j % 2 == 0 )); then
            exist=false
            if [ x"${acc_map[$el]}" != x"" ]; then
                cid=$(echo $el | xxd -r -p)
                echo $cid >> $TMPFILE2
                exist=true
            fi
        elif $exist; then
            lest_order_blk=$(max $lest_order_blk $el)
        fi
        ((j++))
    done
    ((file_num=file_num+${#acc_map[@]}))
    echo " Done: file number(current:${#acc_map[@]}, total:$file_num), latest block:$lest_report_blk"
    unset acc_map
    if [ $lest_report_blk -gt 0 ]; then
        id_2_lblk[$id]=$lest_report_blk
    fi
    fetched_latest_blk=$(max $fetched_latest_blk $lest_order_blk)
done
cat $TMPFILE2 | sort | uniq > $owned_cids_file
if [ x"$fetch_start_blk_n" = x"" ]; then
    fetch_start_blk_n=$fetched_latest_blk
fi
if [ x"$fetch_start_blk_o" = x"" ]; then
    fetch_start_blk_o=$fetch_start_blk_n
fi
echo "INFO: newest order block:$fetch_start_blk_n"

### Get old orders from the latest order block
order_step=200
number_cur=0
spower_cur=0
new_order_num=0
new_order_size=0
enough=false
declare -A id_2_cids
declare -A id_2_size
true > $add_files_script
if [ $break_cond -eq 0 ]; then
    cond="{_gt:\\\"$fetch_start_blk_n\\\"}},order_by:{blockNumber:asc}"
    echo "INFO: search newer order from block:$fetch_start_blk_n"
else
    cond="{_lt:\\\"$fetch_start_blk_o\\\"}},order_by:{blockNumber:desc}"
    echo "INFO: search older order from block:$fetch_start_blk_o"
fi
while ! $enough ; do
    file_arry=($(curl -s -XPOST $subsquid_url --data-raw '{"query": "query MyQuery {\n  substrate_extrinsic(limit: '$order_step', where: {method: {_eq: \"placeStorageOrder\"}, blockNumber: '$cond' ) {\n    args\n    blockNumber\n  }\n}\n"}' 2>/dev/null | jq -r '.data.substrate_extrinsic|.[]|[.args[0].value, .args[1].value, .blockNumber]' 2>/dev/null | jq -r '.[]' 2>/dev/null))
    file_num=${#file_arry[@]}
    if [ $file_num -gt 0 ]; then
        if [ $break_cond -eq 0 ]; then
            echo "INFO: fetched new order range => $fetch_start_blk_n ~ ${file_arry[2]}"
            fetch_start_blk_n=${file_arry[2]}
            cond="{_gt:\\\"$fetch_start_blk_n\\\"}},order_by:{blockNumber:asc}"
        else
            echo "INFO: fetched old order range => $fetch_start_blk_o ~ ${file_arry[$((file_num-1))]}"
            fetch_start_blk_o=${file_arry[$((file_num-1))]}
            cond="{_lt:\\\"$fetch_start_blk_o\\\"}},order_by:{blockNumber:desc}"
        fi
        i=0
        added=false
        for el in ${file_arry[@]}; do
            if ((i % 3 == 0)); then
                added=false
                cid=$(echo $el | xxd -r -p)
                if ! grep $cid $owned_cids_file &>/dev/null; then
                    tag=$(get_number_by_cid $cid 3)
                    ((tag=tag%${#member_ids[@]}))
                    id=${member_ids[$tag]}
                    if ! echo ${id_2_cids[$id]} | grep $cid &>/dev/null; then
                        id_2_cids[$id]="${id_2_cids[$id]}$cid "
                        ((number_cur++))
                        added=true
                    fi
                fi
            elif ((i % 3 == 1)); then
                if $added; then
                    ((spower_cur=spower_cur+$el))
                    id_2_size[$id]=$((${id_2_size[$id]}+$el))
                fi
            else
                if is_enough; then enough=true; fi
                if $enough; then
                    if [ $break_cond -eq 0 ]; then
                        fetch_start_blk_n=$el
                    else
                        fetch_start_blk_o=$el
                    fi
                    break
                fi
            fi
            ((i++))
        done
    elif [ $break_cond -lt 1 ]; then
        new_order_num=$number_cur
        new_order_size=$spower_cur
        ((break_cond++))
        cond="{_lt:\\\"$fetch_start_blk_o\\\"}},order_by:{blockNumber:desc}"
        echo "INFO: search older order from block:$fetch_start_blk_o"
    else
        echo "INFO: no more files can be found, or network issue, please try again"
        break
    fi
done
if [ $break_cond -eq 0 ]; then
    new_order_num=$number_cur
    new_order_size=$spower_cur
fi
echo "INFO: get order number:$number_cur, size:$spower_cur"
echo "      new order number:$new_order_num, size:$new_order_size"
echo "      old order number:$((number_cur-new_order_num)), size:$((spower_cur-new_order_size))"

### Generate add script
if [ ${#id_2_cids[@]} -gt 0 ]; then
cat << EOF > $add_files_script
#!/bin/bash
declare -A id_2_cids
account=\$(curl -s http://localhost:12222/api/v0/enclave/id_info | jq .account)
if [ x"\$account" = x"" ]; then
    echo "ERROR: get sWorker account failed, please make sure sWorker is running!"
    exit 1
fi
echo "INFO: account:\$account"

$(
    for id in ${!id_2_cids[@]}; do
        echo "id_2_cids[$id]=\"${id_2_cids[$id]}\""
        echo "id_2_size[$id]=\"${id_2_size[$id]}\""
    done
)

cids=(\${id_2_cids[\$account]})
echo "INFO: adding spower:\${id_2_size[\$account]}"
for cid in \${cids[@]}; do
    curl -XPOST 'http://127.0.0.1:42087/api/v0/insert' --data-raw '{"cid" : "'\$cid'"}'
done
EOF
fi
chmod +x $add_files_script
{
    true > $prev_meta_file
    for id in ${!id_2_lblk[@]}; do
        echo "id_2_lblk[$id]=${id_2_lblk[$id]}"
    done
    echo "fetch_start_blk_o=$fetch_start_blk_o"
    echo "fetch_start_blk_n=$fetch_start_blk_n"
} > $prev_meta_file

echo -e "INFO: ${HGREEN}add scripts has been generated at:${add_files_script}, copy and execute this script in your member machine to gain more spower.${NC}"
