#!/bin/bash

. bin/utils.sh

# Some configuration
crust_main_install_dir="/opt/crust"
crust_resource_dir="resource"
crust_bin="$crust_resource_dir/crust"
crust_api_package="$crust_resource_dir/crust-api.tar"
crust_api_resource_dir="$crust_resource_dir/crust-api"
crust_tee_package="$crust_resource_dir/crust-tee.tar"
crust_tee_resource_dir="$crust_resource_dir/crust-tee"

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
  verbose ERROR "Resource folder dosen't exist!"
  exit 1
fi

if [ ! -f "$crust_bin" ]; then
  verbose ERROR "Crust bin dosen't exist!"
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
verbose INFO " SUCCESS\n" t

# Install crust TEE
verbose INFO "---------- Installing crust TEE ----------" n
verbose INFO "Unzip crust TEE package" h
tar -xvf "$crust_tee_package" -C "$crust_resource_dir/" &>/dev/null
verbose INFO " SUCCESS" t
./$crust_tee_resource_dir/install.sh
rm -rf $crust_tee_resource_dir

# Install crust chain
verbose INFO "---------- Installing crust chain ----------" n
verbose INFO "Move crust chain bin to aim folder" h
cp "$crust_bin" "$crust_main_install_dir/"
verbose INFO " SUCCESS\n" t

# Install crust API
verbose INFO "---------- Installing crust API ----------" n
verbose INFO "Unzip crust API package" h
tar -xvf "$crust_api_package" -C "$crust_resource_dir/" &>/dev/null
verbose INFO " SUCCESS" t
rm -rf $crust_api_resource_dir
