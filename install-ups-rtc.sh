#!/bin/sh
# Enable I2C functions and RTC (ds1307), then install prerequisites and UPS scripts/service.
# Script for Raspberry Pi 4B + EP-0136
#
# What each script/service do:
#   - [/etc/systemd/system/ups-monitor.service]
#       Systemd service file to monitor UPS battery level every minute
#       then trigger shutdown if low battery, and create logs
#   - [/etc/systemd/system/ups-rtc.service]
#       Systemd service file to make OS recognize about UPS RTC device
#   - [/etc/modules-load.d/*.conf]
#       Modules needed for I2C
#   - [/usr/local/sbin/ups-monitor]
#       A python3 script for monitor service
#   - [/usr/local/sbin/ups-reg]
#       A shell script to read/write raw data of UPS through i2cget/i2cset
#   - [/lib/systemd/system-shutdown/ups-poweroff-on-linux-shutdown]
#       Send poweroff signal to UPS when linux shutdown is triggered
#   - [/etc/logrotate.d/ups-monitor]
#       Do logrotate for ups-monitor
#
# Script both for RHEL family && Debian family
#   - Tested on following images:
#     - Rocky Linux 8.5 on Raspberry Pi (64-bit) [Release Date 2021-11-16]
#     - Raspberry Pi OS Lite (64-bit) [Release Date 2022-04-04]
#     - Ubuntu Server 20.04.4 LTS (64-bit) [Release Date 2022-02-23]
#   - Error on following image:
#     - Oracle Linux 8.5 [Release Date 2021-11-16]
#   - It is recommended to run this script on unconfigured, clean OS images (tested above),
#     although there should be no critical problem when applied to already configured systems.
#
# Run as root (sudo).


# check if config file (format of key1=value1,value2,...) already has given flag enabled
append_if_not_exist () {
	if ! grep -E "^$1=(|.*\,)$2(|\,.*)\$" "$3" > /dev/null 2>&1
	then
		printf "%s=%s\n" "$1" "$2" >> "$3"
	else
		printf "'%s=%s' already exists in '%s'!\n" "$1" "$2" "$3" 1>&2
	fi

	# check and return result
	grep -E "^$1=(|.*\,)$2(|\,.*)\$" "$3" > /dev/null 2>&1
}

# Check root
if [ "$(id -u)" -ne "0" ]
then
	printf "Run as root!\n" 1>&2
	exit 1
fi

# Check working dir
if [ ! -d fsroot-ups ]
then
	printf "No fsroot-ups found! Run this script inside its directory.\n" 1>&2
	exit 1
fi

# Check arg
CONFIRM_OVERRIDE_OPT="-i"
if [ "$#" -gt 0 ] && [ "$1" = "-f" ]
then
        CONFIRM_OVERRIDE_OPT=
fi



# Enable i2c after next boot
if ! (

append_if_not_exist "dtparam" "i2c_arm=on" '/boot/config.txt' &&
append_if_not_exist "dtoverlay" "i2c-rtc" '/boot/config.txt' &&
append_if_not_exist "dtoverlay" "ds1307" '/boot/config.txt'

) then printf "Failed to write to /boot/config.txt!\n" 1>&2 && exit 2; fi



# Additional prerequisites
if ! (

# Install prerequisites (for RHEL family)
( command -v yum > /dev/null 2>&1 &&
	yum install -y gcc gcc-c++ cmake make python3 python3-devel python3-pip i2c-tools ) ||
# Install prerequisites (for Debian family)
( command -v apt > /dev/null 2>&1 && apt update &&
	apt install -y gcc g++ cmake make python3 python3-dev python3-pip i2c-tools )

) then printf "%s%s"\
	"Failed to install prerequisites!\n"\
	"Check if connected to internet, or other package manager process is running.\n" 1>&2 &&
	exit 2; fi



# Common python3 prerequisites
if ! (

pip3 install smbus2 pi-ina219

) then printf "Failed to install python3 prerequisites!\n" 1>&2 && exit 2; fi


# Install scripts and services
if ! (

( cd fsroot-ups/ || exit 1;
	find . -type d -exec mkdir -p /{} \; && find . -type f -exec cp $CONFIRM_OVERRIDE_OPT {} /{} \; ) &&
systemctl daemon-reload &&
systemctl enable ups-monitor.service &&
systemctl enable ups-rtc.service

) then printf "Failed to install scripts/services!\n" 1>&2 && exit 2; fi





printf "\n\n\n *** Reboot is recommended to use installed script! ***\n" 1>&2
