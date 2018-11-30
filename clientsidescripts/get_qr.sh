#!/bin/bash

#Usage
#This script will generate a unique QR code and display qr code and make client to listen to DPP, save the configuration information to conf fileon connection establishment.
#To generate a QR-Code of  STA-client and make it into listen mode run the following command line arguments
# ./get_qr.sh <path/of/supplicant/> <path to supplicant config file/>


#killing
sudo pkill wpa_supplicant
sudo airmon-ng check kill
sudo rm -rf /var/run/wpa_supplicant
sleep 3

WPA_BASEDIR=$1
KEYOFCLIENTDEVICE=30770201010420b44caad64bdcac9d824ab00147d5ae813817eb4ac3b7a623ac28c4dffe080c6ea00a06082a8648ce3d030107a144034200042926c15b1ed896b04d51edfcbbbb4adff8cebbf331d4a823732788b17e3279c80c1927074b77b4f37ad7914ee61fd8aa9bb7eb3418ed886c2012136d1b0da000

#getting interface name and mac address
echo "Select the interface ID "
LISTOFINTERFACES=$(ls -1 /sys/class/net)
INTERFACECOUNT=0
for I in ${LISTOFINTERFACES[@]}
do
	echo "${INTERFACECOUNT} - $I"
	INTERFACECOUNT=$(expr $INTERFACECOUNT + 1)
done
read -p "Enter interface ID: " INTERFACEID
echo $INTERFACEID
INTERFACECOUNT=0
for LOOPINGINTERFACE in ${LISTOFINTERFACES[@]}
do
	if [ $INTERFACECOUNT == $INTERFACEID ]; then
		INTERFACE=$LOOPINGINTERFACE
		break;
	fi
	INTERFACECOUNT=$(expr $INTERFACECOUNT + 1)
done
echo "The selected interface is $INTERFACE"
if [ -z "$INTERFACE" ];then
	echo "Exiting gracefully"
	exit 0
fi
MACADDRESS=`cat /sys/class/net/$INTERFACE/address`

echo $MACADDRESS
#Running wpa_supplicant
sudo $WPA_BASEDIR/wpa_supplicant -Dnl80211 -i$INTERFACE -c $2 &
sleep 3

# Generating a unique QR code
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
sudo $WPA_BASEDIR/wpa_cli dpp_listen 2412
display qrcode.jpeg &

#This loop will check the connection status every 2 seconds. Once a sucessfull connection happens, the configuration is saved into the config file.
#Writing to config file is for persisting DPP configuration
while true;
do
	STATUS=$(sudo $WPA_BASEDIR/wpa_cli status)
	WPASTATUS=${STATUS##*wpa_state=}
	WPASTATUS=$(echo $WPASTATUS | cut -f 1 -d " ")
	echo "The current  status is $WPASTATUS"
	if [ $WPASTATUS == "COMPLETED" ]; then
		GETTINGID=${STATUS##*id=}
		GETTINGID=$(echo $GETTINGID | cut -f 1 -d " ")
		echo "The network ID is $GETTINGID"
		sudo $WPA_BASEDIR/wpa_cli save_config $GETTINGID
		break
	fi
	sleep 2;
done
