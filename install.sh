#!/bin/bash

. bin/utils.sh

# Some configuration
crust_resource_dir="resource"
crust_bin="$crust_resource_dir/crust"
crust_api_package="$crust_resource_dir/crust-api.tar"
crust_tee_package="$crust_resource_dir/crust-tee.tar"

# Get crust resources
crust_version=$1
if [ -z $crust_version ]; then
    verbose INFO "Try to use the local resources to install" *
else
    verbose INFO "Try to download online resources to install" *
    # TODO: Download resources into resource folder
fi

# Check the resources
verbose INFO "Check the resources" *
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

# Install Crust TEE
verbose INFO "Try to install Crust TEE" *
