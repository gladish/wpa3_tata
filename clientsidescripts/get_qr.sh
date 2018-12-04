#!/bin/bash

#Usage
#This script will generate a unique QR code and display qr code and make client to listen to DPP, save the configuration information to conf fileon connection establishment.
#To generate a QR-Code of  STA-client and make it into listen mode run the following command line arguments
# ./get_qr.sh <path to supplicant config file/> <path/of/hostap/>


if [ $# -ne 2  ]; then
	echo "Invalid number of command line arguements."
	echo "Run in the format ./get_qr.sh <path/to/supplicant.conf> <path/of/hostap/>"
	exit 0
fi

#killing
echo "Killing previous  instance of wpa_supplicant"
sudo pkill wpa_supplicant
sudo airmon-ng check kill
sudo rm -rf /var/run/wpa_supplicant
echo "Killed previous  instance of wpa_supplicant"

TOPDIR=$2
WPA_BASEDIR=${TOPDIR}/wpa_supplicant/

#getting interface name and mac address
echo "Select the interface ID of supplicant"
LISTOFINTERFACES=$(ls -1 /sys/class/net)
INTERFACECOUNT=0
## The LISTOFINTERFACES is not a valid array. It is converted to an array
for I in ${LISTOFINTERFACES[@]}
do
	INTERFACEARRAY[INTERFACECOUNT]=$I
	echo "${INTERFACECOUNT} - $I"
	INTERFACECOUNT=$(expr $INTERFACECOUNT + 1)
done
read -p "Enter interface ID: " INTERFACEID
INTERFACE=${INTERFACEARRAY[INTERFACEID]}
echo "The selected interface is $INTERFACE"
if [ -z "$INTERFACE" ];then
	echo "Please enter a valid interface number"
	exit 0
fi
MACADDRESS=`cat /sys/class/net/$INTERFACE/address`


#Running wpa_supplicant
echo "Starting wpa_supplicant"
sudo $WPA_BASEDIR/wpa_supplicant -Dnl80211 -i$INTERFACE -c $1 &
#wpa_cli ping command will return "PONG" if supplicant is up
#If supplicant is not up, it will return error. So check for "PONG"
SUPPLICANT_STATUS_CHECK_OUTPUT=$(sudo $WPA_BASEDIR/wpa_cli ping | grep -i PONG)
while [ "${SUPPLICANT_STATUS_CHECK_OUTPUT}" != "PONG" ]
do
	echo "Supplicant not up. Waiting..."
	sleep 1
	SUPPLICANT_STATUS_CHECK_OUTPUT=$(sudo $WPA_BASEDIR/wpa_cli ping |grep -i PONG)
done

echo "Started wpa_supplicant successfully"

echo "Checking private key for QR code generation"
if [ -s ~/privatekey ]; then
	echo "Private key is found in device."
	KEYOFCLIENTDEVICE=`cat ~/privatekey`
else
	echo "No private key found in device. Generating new private key"
	# A configurator is just created to get a valid private key. The configurator is never used
	sudo $WPA_BASEDIR/wpa_cli dpp_configurator_add
	KEYOFCLIENTDEVICE=$(sudo $WPA_BASEDIR/wpa_cli dpp_configurator_get_key 1 | grep -v 'Selected')
fi
echo "${KEYOFCLIENTDEVICE}" > ~/privatekey


# Generating a unique QR code
echo "Generating QR code for the device"
sudo $WPA_BASEDIR/wpa_cli dpp_bootstrap_gen type=qrcode mac=$MACADDRESS chan=81/1 key=$KEYOFCLIENTDEVICE
# Storing the QR code in a file
sudo $WPA_BASEDIR/wpa_cli dpp_bootstrap_get_uri 1 | grep "DPP" > /tmp/qrcode
# Generating JPEG QR image
if [ -s /tmp/qrcode ]; then
	qrencode -o qrcode.jpeg < /tmp/qrcode
else
	echo "Creating qrcode failed"
	exit
fi
#Making client into listen body
echo "Making client listen to DPP"
sudo $WPA_BASEDIR/wpa_cli dpp_listen 2412
echo "Displaying QR code"
display qrcode.jpeg &

#This loop will check the connection status every 2 seconds. Once a sucessfull connection happens, the configuration is saved into the config file.
#Writing to config file is for persisting DPP configuration
while true;
do
	STATUS=$(sudo $WPA_BASEDIR/wpa_cli status)
	WPASTATUS=${STATUS##*wpa_state=}
	WPASTATUS=$(echo $WPASTATUS | cut -f 1 -d " ")
	echo "The current supplicant status is $WPASTATUS"
	if [ $WPASTATUS == "COMPLETED" ]; then
		GETTINGID=${STATUS##*id=}
		GETTINGID=$(echo $GETTINGID | cut -f 1 -d " ")
		echo "The network ID is $GETTINGID"
		echo "Saving the configuration"
		sudo $WPA_BASEDIR/wpa_cli save_config $GETTINGID
		echo "Getting IP address"
		sudo dhclient $INTERFACE
		echo "Connected sucessfully to AP."
		break
	fi
	sleep 2;
done
