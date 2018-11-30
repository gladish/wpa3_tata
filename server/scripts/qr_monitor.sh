#!/bin/bash

#Usage
#This script will monitor the received QR-Code from Client devices and authenticate the STA device. The configuration and network introduction protocol happens after authentication.
#To scan a QR-Code of  STA-client and authenticate, provisioning, and for network introduction using hostapd(AP) as configurator run run the following command line arguments
#./qr_monitor.sh <qr_code> <path/of/hostapd> <dppsecurity> <password>

password=$4
hostapd_basedir=${2}/hostapd/hostapd_cli
DPPSecurity=$3
#Checks whethere any configurator private keys are present for AP to act as configurator. When AP gets DPP configuration, the configkeys are stored in the home directory
if [ ! -f ~/configkeys ]; then
	    echo "No key for configurator found. Please configure AP"
	    exit 0
fi
#The private key of configurator is read
privateKeyOfConfigurator=`cat ~/configkeys`
#The configurator is created
sudo $hostapd_basedir dpp_configurator_add key=$privateKeyOfConfigurator
# Adding QR code to the AP Hostapd console
gettingQRcode=$(sudo $hostapd_basedir dpp_qr_code "$1")
# Getting QR code ID
qrCodeID=$(echo -n $gettingQRcode | tail -c 1)
echo "Getting SSID information of AP"
configuration=$(sudo $hostapd_basedir get_config);
echo "The complete AP configuration is $configuration"
#Getting SSID value from the complete configuration
ssid=${configuration##*ssid=}
#Get the first word by using ' ' as the delimited
ssid=$(echo $ssid | cut -f 1 -d " ")
echo "The SSID of AP is $ssid"
#Getting the hexval of SSID
hexvalssid=$(echo -n "$ssid" |xxd -p -u)
echo "The SSID hexval is $hexvalssid"
#Sending DPP configuration
echo $DPPSecurity
if [ $DPPSecurity == "dppconnector" ]; then
	echo "Using DPP connector "
	sudo $hostapd_basedir dpp_auth_init peer=$qrCodeID configurator=1 conf=sta-dpp ssid=$hexvalssid
fi
if [ $DPPSecurity == "wpapsk" ]; then
	echo "Using DPP WPA-PSK"
	hexvalpsk=$(echo -n "$password" |xxd -p -u)
	sudo $hostapd_basedir dpp_auth_init peer=$qrCodeID configurator=1 conf=sta-psk ssid=$hexvalssid pass=$hexvalpsk
fi
if [ $DPPSecurity == "wpasae" ]; then
	echo "Using DPP WPA-SAE"
	hexvalpsk=$(echo -n "$password" |xxd -p -u)
	sudo $hostapd_basedir dpp_auth_init peer=$qrCodeID configurator=1 conf=sta-sae ssid=$hexvalssid pass=$hexvalpsk
fi

