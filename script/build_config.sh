#!/bin/bash

# Install denpendencies

verbose INFO "Install jq ... " h
res=0
apt-get install jq &>/dev/null
res=$(($?|$res))
checkRes $res "quit" "success"

# Build chain configuration
