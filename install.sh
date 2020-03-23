#!/bin/bash

. script/utils.sh

# Some configuration
user_dir=$(pwd)
uid=$(stat -c '%U' $user_dir)
tool_dir="tool"

crust_main_install_dir="/opt/crust"
crust_chain_main_install_dir="$crust_main_install_dir/crust"
crust_tee_main_install_dir="$crust_main_install_dir/crust-tee"
crust_api_main_install_dir="$crust_main_install_dir/crust-api"
crust_client_main_install_dir="$crust_main_install_dir/crust-client"

crust_resource_dir="resource"
crust_chain_package="$crust_resource_dir/crust.tar"
crust_chain_resource_dir="$crust_resource_dir/crust"
crust_api_package="$crust_resource_dir/crust-api.tar"
crust_api_resource_dir="$crust_resource_dir/crust-api"
crust_tee_package="$crust_resource_dir/crust-tee.tar"
crust_tee_resource_dir="$crust_resource_dir/crust-tee"

crust_subkey_bin="$crust_resource_dir/crust-subkey"
crust_subkey_bin_aim="/usr/bin/crust-subkey"

crust_client_sh="script/crust-client.sh"
crust_client_aim="/usr/bin/crust-client"

trap '{ echo "\nHey, you pressed Ctrl-C.  Time to quit." ; exit 1; }' INT

if [ $(id -u) -ne 0 ]; then
    verbose ERROR "Please run with sudo!"
    exit 1
fi

# Test sgx environment
gcc $tool_dir/test-sgx.c -o $tool_dir/test-sgx.o
./$tool_dir/test-sgx.o &>/dev/null
sgx_check_res=$?
if [ $sgx_check_res -eq 1 ]; then
    verbose ERROR "CPU SGX functions are deactivated or SGX is not supported!"
    exit 1
elif [ $sgx_check_res -eq 2 ]; then
    verbose ERROR "SGX is available for your CPU but not enabled in BIOS!"
    exit 1
elif [ $sgx_check_res -eq 0 ]; then
    verbose INFO "SGX is available for your CPU and enabled in BIOS!"
else
    verbose ERROR "SGX check has unkown error!"
    exit 1
fi

# Get crust resources
verbose INFO "---------- Getting resource ----------" n
crust_version=$1
if [ -z $crust_version ]; then
    verbose INFO "Try to use the local resources to install" h
else
    verbose INFO "Try to download online resources to install" h
    # TODO: Download resources into resource folder
fi
verbose INFO " SUCCESS" t

# Check the resources
verbose INFO "Check the resources" h
if [ ! -d "$crust_resource_dir" ]; then
  verbose ERROR "Resource folder dosen't exist! Please go to this page (https://github.com/crustio/crust-client/releases) to download 'resource.tar' and unzip it."
  exit 1
fi

if [ ! -f "$crust_chain_package" ]; then
  verbose ERROR "Crust chain package dosen't exist!"
  exit 1
fi

if [ ! -f "$crust_api_package" ]; then
  verbose ERROR "Crust API package dosen't exist!"
  exit 1
fi

if [ ! -f "$crust_tee_package" ]; then
  verbose ERROR "Crust TEE package dosen't exist!"
  exit 1
fi

if [ ! -f "$crust_subkey_bin" ]; then
  verbose ERROR "Crust subkey bin dosen't exist!"
  exit 1
fi

verbose INFO " SUCCESS\n" t

# Install crust TEE
verbose INFO "---------- Installing crust TEE ----------" n
if [ -d "$crust_tee_resource_dir" ]; then
  rm -rf $crust_tee_resource_dir
fi

verbose INFO "Unzip crust TEE package" h
tar -xvf "$crust_tee_package" -C "$crust_resource_dir/" &>/dev/null
verbose INFO " SUCCESS\n" t

verbose INFO "Run crust TEE install package" h
./$crust_tee_resource_dir/install.sh
if [ $? -ne 0 ]; then
  verbose ERROR " Failed" t
  exit 1
fi
verbose INFO " SUCCESS" t

rm -rf $crust_tee_resource_dir
chown -R $uid:$uid $crust_main_install_dir

# Install crust chain
verbose INFO "---------- Installing crust chain ----------" n
if [ -d "$crust_chain_resource_dir" ]; then
  rm -rf $crust_chain_resource_dir
fi

verbose INFO "Unzip crust chain package" h
tar -xvf "$crust_chain_package" -C "$crust_resource_dir/" &>/dev/null
verbose INFO " SUCCESS" t

if [ -d "$crust_chain_main_install_dir" ]; then
  verbose INFO "Uninstall old crust chain" h
  rm -rf $crust_chain_main_install_dir
  verbose INFO " SUCCESS" t
fi

verbose INFO "Move crust chain to aim folder: $crust_chain_main_install_dir" h
cp -r $crust_chain_resource_dir $crust_main_install_dir
verbose INFO " SUCCESS\n" t
rm -rf $crust_chain_resource_dir
chown -R $uid:$uid $crust_chain_main_install_dir

# Install crust API
verbose INFO "---------- Installing crust API ----------" n

if [ -d "$crust_api_resource_dir" ]; then
  rm -rf $crust_api_resource_dir
fi

verbose INFO "Unzip crust API package" h
tar -xvf "$crust_api_package" -C "$crust_resource_dir/" &>/dev/null
verbose INFO " SUCCESS" t

if [ -d "$crust_api_main_install_dir" ]; then
  verbose INFO "Uninstall old crust API" h
  rm -rf $crust_api_main_install_dir
  verbose INFO " SUCCESS" t
fi

verbose INFO "Move crust API to aim folder: $crust_api_main_install_dir" h
cp -r $crust_api_resource_dir $crust_main_install_dir
verbose INFO " SUCCESS\n" t
rm -rf $crust_api_resource_dir
chown -R $uid:$uid $crust_api_main_install_dir

# Install crust client
verbose INFO "---------- Installing crust client ----------" n
if [ -d "$crust_client_main_install_dir" ]; then
  verbose INFO "Uninstall old crust client" h
  rm -rf $crust_client_main_install_dir
  if [ -f "$crust_client_aim" ]; then
    rm $crust_client_aim
  fi
  verbose INFO " SUCCESS" t
fi

verbose INFO "Create client directory $crust_client_main_install_dir" h
mkdir $crust_client_main_install_dir
verbose INFO " SUCCESS" t

verbose INFO "Move crust-client files to aim folder: $crust_client_main_install_dir" h
cp VERSION $crust_client_main_install_dir
cp -r etc/ $crust_client_main_install_dir
cp -r script $crust_client_main_install_dir
verbose INFO " SUCCESS" t

verbose INFO "Create crust chain raw spec" n
$crust_chain_main_install_dir/bin/crust build-spec --chain $crust_client_main_install_dir/etc/crust_chain_spec.json --raw > $crust_client_main_install_dir/etc/crust_chain_spec_raw.json
if [ $? -ne 0 ]; then
  verbose ERROR " Failed" t
  exit 1
fi
verbose INFO " SUCCESS" t

verbose INFO "Move crust-subkey bin to /usr/bin" h
cp $crust_subkey_bin $crust_subkey_bin_aim
verbose INFO " SUCCESS\n" t

verbose INFO "Move crust-client runnable script to /usr/bin" h
cp $crust_client_sh $crust_client_aim
verbose INFO " SUCCESS\n" t
chown -R $uid:$uid $crust_client_main_install_dir
