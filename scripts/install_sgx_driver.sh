#!/bin/bash

. $scriptdir/utils.sh

is_16=`cat /etc/issue | grep 16.04`
is_18=`cat /etc/issue | grep 18.04`
is_20=`cat /etc/issue | grep 20.04`
if [ x"$is_16" != x"" ]; then
    driverbin=sgx_linux_x64_driver_2.6.0_b0a445b.bin
    driverurl=https://download.01.org/intel-sgx/sgx-linux/2.11/distro/ubuntu16.04-server/$driverbin
    log_info "Current system is ubuntu 16.04"
elif [ x"$is_18" != x"" ]; then
    driverbin=sgx_linux_x64_driver_2.6.0_b0a445b.bin
    driverurl=https://download.01.org/intel-sgx/sgx-linux/2.11/distro/ubuntu18.04-server/$driverbin
    log_info "Current system is ubuntu 18.04"
elif [ x"$is_20" != x"" ]; then
    driverbin=sgx_linux_x64_driver_2.11.0_4505f07.bin
    driverurl=https://download.01.org/intel-sgx/sgx-linux/2.12/distro/ubuntu20.04-server/$driverbin
    log_info "Current system is ubuntu 20.04"
else
    log_err "Crust sworker can't support this system!"
    exit 1
fi

log_info "Download sgx driver"
if [ -f "$driverbin" ]; then
    rm $driverbin
fi
wget $driverurl

if [ $? -ne 0 ]; then
    log_err "Download sgx dirver failed"
    exit 1
fi

log_info "Installing denpendencies..."
apt-get install -y wget build-essential kmod linux-headers-`uname -r`
if [ $? -ne 0 ]; then
    log_err "Install sgx driver dependencies failed"
    exit 1
fi

log_info "Give sgx driver executable permission"
chmod +x $driverbin

log_info "Installing sgx driver..."
./$driverbin

if [ $? -ne 0 ]; then
    log_err "Install sgx dirver bin failed"
    exit 1
fi

log_info "Clear resource"
rm $driverbin

exit 0
