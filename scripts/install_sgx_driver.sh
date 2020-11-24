#!/bin/bash
scriptdir=$(cd `dirname $0`;pwd)
basedir=$(cd $scriptdir/..;pwd)

is_16=`cat /etc/issue | grep 16.04`
if [ x"$is_16" = x"" ]; then
    driverbin=sgx_linux_x64_driver_2.6.0_b0a445b.bin
    driverurl=https://download.01.org/intel-sgx/sgx-linux/2.11/distro/ubuntu18.04-server/$driverbin
else
    driverbin=sgx_linux_x64_driver_2.6.0_b0a445b.bin
    driverurl=https://download.01.org/intel-sgx/sgx-linux/2.11/distro/ubuntu16.04-server/$driverbin
fi

. $scriptdir/utils.sh

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
