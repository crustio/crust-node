#!/bin/bash

source /opt/crust/crust-node/scripts/utils.sh

is_16=`cat /etc/issue | grep 16.04`
is_18=`cat /etc/issue | grep 18.04`
is_20=`cat /etc/issue | grep 20.04`

attestation_mode=$(getSGXAttestationMode)
if [ x"$attestation_mode" = x"ecdsa" ]; then
    # If the kernel supports SGX DCAP driver, then skip install sgx driver
    if checkKernelSupportSGXDriver; then
        echo "Kernel supports SGX DCAP driver by default, skip install sgx driver"
        exit 0
    fi
fi

if [ x"$is_16" != x"" ]; then
    if [ x"$attestation_mode" = x"ecdsa" ]; then
        driverbin=sgx_linux_x64_driver_1.36.2.bin
        driverurl=https://download.01.org/intel-sgx/sgx-dcap/1.9/linux/distro/ubuntu16.04-server/$driverbin
    else
        driverbin=sgx_linux_x64_driver_2.6.0_b0a445b.bin
        driverurl=https://download.01.org/intel-sgx/sgx-linux/2.11/distro/ubuntu16.04-server/$driverbin
    fi
    log_info "Current system is ubuntu 16.04"
elif [ x"$is_18" != x"" ]; then
    if [ x"$attestation_mode" = x"ecdsa" ]; then
        driverbin=sgx_linux_x64_driver_1.36.2.bin
        driverurl=https://download.01.org/intel-sgx/sgx-dcap/1.9/linux/distro/ubuntu18.04-server/$driverbin
    else
        driverbin=sgx_linux_x64_driver_2.6.0_b0a445b.bin
        driverurl=https://download.01.org/intel-sgx/sgx-linux/2.11/distro/ubuntu18.04-server/$driverbin
    fi
    log_info "Current system is ubuntu 18.04"
elif [ x"$is_20" != x"" ]; then
    if [ x"$attestation_mode" = x"ecdsa" ]; then
        driverbin=sgx_linux_x64_driver_1.36.2.bin
        driverurl=https://download.01.org/intel-sgx/sgx-dcap/1.9/linux/distro/ubuntu20.04-server/$driverbin
    else
        driverbin=sgx_linux_x64_driver_2.11.0_4505f07.bin
        driverurl=https://download.01.org/intel-sgx/sgx-linux/2.12/distro/ubuntu20.04-server/$driverbin
    fi
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
apt-get install -y wget build-essential kmod dkms linux-headers-`uname -r`
if [ $? -ne 0 ]; then
    log_err "Install sgx driver dependencies failed"
    exit 1
fi

log_info "Give sgx driver executable permission"
chmod +x $driverbin

log_info "Uninstall existing sgx driver..."
# If both OOT driver the DCAP driver exists, sgx_init_enclave would fail to open sgx driver
for mod in $(lsmod | grep -i sgx | awk '{print $1}'); do
    log_info "Uninstall mod '$mod'..."

    rm -f $(find /lib/modules -name $mod.ko)
    /sbin/depmod
    sed -i '/^$mod$/d' /etc/modules
    rm -f /etc/sysconfig/modules/$mod.modules
    rm -f /etc/modules-load.d/$mod.conf
    /opt/intel/sgxdriver/uninstall.sh
done

log_info "Installing sgx driver..."
./$driverbin
if [ $? -ne 0 ]; then
    log_err "Install sgx dirver bin failed"
    exit 1
fi

log_info "Clear resource"
rm $driverbin

exit 0
