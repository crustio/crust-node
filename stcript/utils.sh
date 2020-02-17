#!/bin/bash

### 3 params: json, key, defaultValue
function getJsonValuesByAwk() {
    awk -v json="$1" -v key="$2" -v defaultValue="$3" 'BEGIN{
        foundKeyCount = 0
        while (length(json) > 0) {
            # pos = index(json, "\""key"\"");
            pos = match(json, "\""key"\"[ \\t]*?:[ \\t]*");
            if (pos == 0) {if (foundKeyCount == 0) {print defaultValue;} exit 0;}

            ++foundKeyCount;
            start = 0; stop = 0; layer = 0;
            for (i = pos + length(key) + 1; i <= length(json); ++i) {
                lastChar = substr(json, i - 1, 1)
                currChar = substr(json, i, 1)

                if (start <= 0) {
                    if (lastChar == ":") {
                        start = currChar == " " ? i + 1: i;
                        if (currChar == "{" || currChar == "[") {
                            layer = 1;
                        }
                    }
                } else {
                    if (currChar == "{" || currChar == "[") {
                        ++layer;
                    }
                    if (currChar == "}" || currChar == "]") {
                        --layer;
                    }
                    if ((currChar == "," || currChar == "}" || currChar == "]") && layer <= 0) {
                        stop = currChar == "," ? i : i + 1 + layer;
                        break;
                    }
                }
            }

            if (start <= 0 || stop <= 0 || start > length(json) || stop > length(json) || start >= stop) {
                if (foundKeyCount == 0) {print defaultValue;} exit 0;
            } else {
                print substr(json, start, stop - start);
            }

            json = substr(json, stop + 1, length(json) - stop)
        }
    }'
}

function checkRes()
{
    local res=$1
    local err_op=$2
    local descriptor=$3

    if [ x"$descriptor" = x"" ] ; then 
        descriptor="&1"
    fi

    if [ $res -ne 0 ]; then
        eval "verbose ERROR "FAILED" t >$descriptor"
        case $err_op in 
            quit)       exit 1;;
            return)     return 1;;
            *)          ;;
        esac
        return 1
    fi

    eval "verbose INFO "SUCCESS" t >$descriptor"

    while [ -s $descriptor ]; do
        sleep 1
    done
}

function verbose()
{
    local type=$1
    local info=$2
    local tips=$3
    local color=$GREEN
    local nc=$NC
    local opt="-e"
    local content=""
    local time=`date "+%Y/%m/%d %T.%3N"`

    case $type in
        ERROR)  color=$RED ;;
        WARN)   color=$YELLOW ;;
        INFO)   color=$GREEN ;;
    esac
    case $tips in 
        h)      
            opt="-n"
            content="$time [$type] $info"
            ;;
        t)      
            opt="-e"
            content="${color}$info${nc}"
            ;;
        n)
            content="$time [$type] $info"
            ;;
        *)
            content="${color}$time [$type] $info${nc}"
    esac
    echo $opt $content
}

# color
RED='\033[0;31m'
HRED='\033[1;31m'
GREEN='\033[0;32m'
HGREEN='\033[1;32m'
YELLOW='\033[0;33m'
HYELLOW='\033[1;33m'
NC='\033[0m'

