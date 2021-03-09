#! /usr/bin/env bash
scriptdir=$(cd `dirname $0`;pwd)
basedir=$(cd $scriptdir/..;pwd)
source $scriptdir/utils.sh

log_info "Start generate configurations and docker compose file"
CG_IMAGE="crustio/config-generator:latest"

if [[ "$(docker images -q ${CG_IMAGE} 2> /dev/null)" == "" ]]; then
    log_info "retrieving config generator..."
    docker pull $CG_IMAGE
    if [ $? -ne 0 ]; then
        log_err "Failed to retrieve config generator"
        exit 1
    fi

    log_info "Done retrieve config generator"
fi

if [ ! -f "$basedir/config.yaml" ]; then
    log_err "config.yaml doesn't exists!"
    exit 1
fi

BUILD_DIR=$basedir/build
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

cp -f $basedir/config.yaml $basedir/build/
CIDFILE=`mktemp`
rm $CIDFILE
docker run --cidfile $CIDFILE -i --workdir /opt/output -v $BUILD_DIR:/opt/output $CG_IMAGE node /opt/app/index.js
SUCCESS="$?"
CID=`cat $CIDFILE`
docker rm $CID

if [ "$SUCCESS" -ne "0" ]; then
    log_err "Failed to generate application configs, please check your config.yaml"
    exit 1
fi

<<'COMMENT'
INVALID_PATHS=0
while IFS= read -r line || [ -n "$line" ]; do
    mark=${line:0:1}
    path=${line:2}
    if [ ! -e "$path" ]; then
        if [ "$mark" == "|" ]; then
            log_warn "$path doesn't exist!"
        elif [ "$mark" == "+" ]; then
            log_err "$path doesn't exist!"
            INVALID_PATHS=1
        fi
    fi
done <$BUILD_DIR/.tmp/.paths

if [ $INVALID_PATHS -ne "0" ]; then
    log_err "some paths is not valid, please check your config!"
    exit 1
fi

COMMENT

rm -f $BUILD_DIR/config.yaml
cp -r $BUILD_DIR/.tmp/* $BUILD_DIR/
rm -rf $BUILD_DIR/.tmp
chown -R root:root $BUILD_DIR
chmod -R 0600 $BUILD_DIR

log_success "Configurations generated at: $BUILD_DIR"
