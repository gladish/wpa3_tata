#!/bin/bash
#script for AP-configurting itself
#run the script by running the below command
# ./get_config.sh <path/to/hostapd.conf> <path/of/hostapd/>

#Kill existing process. Wait for some time for it to complete
sudo pkill node
sudo pkill npm
sudo pkill hostapd
sudo airmon-ng check kill
sudo rm -rf /var/run/hostapd
sleep 5

UPLOAD_URL="http://localhost:3000/storeddppcredentials"
DPP_LOGFILE=/tmp/LogFile
TOPDIR=$2
HOSTAPD_FOLDER=${TOPDIR}/hostapd/

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

#Run server
cd ../server; npm start $TOPDIR  &
cd -

#Remove any existing logs in the log file
sudo echo "Start" >$DPP_LOGFILE

#Run hostapd
sudo $HOSTAPD_FOLDER/hostapd -i$INTERFACE $1  | tee  $DPP_LOGFILE &
sleep 5

PIDOFHOSTAPD=$(pidof hostapd)
CHECKDPPVALUES=$(grep -ic 'dpp_connector\|dpp_csign\|dpp_netaccesskey' $1)

if [ $CHECKDPPVALUES -eq 0 -a $PIDOFHOSTAPD ]; then

	if [ -s ~/configkeys ]; then
		PRIVATEKEYOFCONFIGURATOR=`cat ~/configkeys`
		#The configurator is created with existing key
		sudo $HOSTAPD_FOLDER/hostapd_cli dpp_configurator_add key=$PRIVATEKEYOFCONFIGURATOR
	else
		sudo $HOSTAPD_FOLDER/hostapd_cli dpp_configurator_add
		PRIVATEKEYOFCONFIGURATOR=$(sudo $HOSTAPD_FOLDER/hostapd_cli dpp_configurator_get_key 1 | grep -v 'Selected')
	fi

	sudo $HOSTAPD_FOLDER/hostapd_cli dpp_configurator_sign " configurator=1 conf=ap-dpp"
	#Wait for some time to complete the configuration process
	sleep 3

	#By this time you should have the logs populated. Grep for connector,netaccess key and csign
	DPP_CONNECTOR=$(grep -o "DPP-CONNECTOR.*"  $DPP_LOGFILE)
	DPPCONNECTORPREFIX="DPP-CONNECTOR "
	DPP_CONNECTOR=${DPP_CONNECTOR#"$DPPCONNECTORPREFIX"}
	echo "DPP_CONNECTOR = $DPP_CONNECTOR"

	DPP_NETACCESSKEY=$(grep -o "DPP-NET-ACCESS-KEY.*"  $DPP_LOGFILE)
	DPPNETACCESSKEYPREFIX="DPP-NET-ACCESS-KEY "
	DPP_NETACCESSKEY=${DPP_NETACCESSKEY#"$DPPNETACCESSKEYPREFIX"}
	echo "DPP_NETACCESSKEY = $DPP_NETACCESSKEY"

	DPP_CSIGN=$(grep -o "DPP-C-SIGN-KEY.*"  $DPP_LOGFILE)
	DPPCSIGNPREFIXPREFIX="DPP-C-SIGN-KEY "
	DPP_CSIGN=${DPP_CSIGN#"$DPPCSIGNPREFIXPREFIX"}
	echo "DPP_CSIGN = $DPP_CSIGN"

	#Setting the dppconnectorvalue, dppcsignvalue and dppnetaccesskey at run time.
	sudo $HOSTAPD_FOLDER/hostapd_cli set "dpp_connector" ${DPP_CONNECTOR}
	sudo $HOSTAPD_FOLDER/hostapd_cli set "dpp_csign" ${DPP_CSIGN}
	sudo $HOSTAPD_FOLDER/hostapd_cli set "dpp_netaccesskey" ${DPP_NETACCESSKEY}

	# Writing dppconnectorvalue, dppcsignvalue, dppnetaccesskey to config file of AP. To persist after reboot
	echo "dpp_connector="${DPP_CONNECTOR}"" >> $1
	echo "dpp_csign="${DPP_CSIGN}"" >> $1
	echo "dpp_netaccesskey="${DPP_NETACCESSKEY}"" >> $1

	#Send the command to server
	DATA_TO_UPLOAD="'{\"dppconfigkey\":\"${PRIVATEKEYOFCONFIGURATOR}\",\"dppconnector\":\"${DPP_CONNECTOR}\",\"dppnetaccesskey\":\"${DPP_NETACCESSKEY}\",\"dppcsign\":\"${DPP_CSIGN}\", \"macaddress\":\"${MACADDRESS}\"}'"
	COMMAND="curl --header \"Content-Type: application/json\" --request POST --data ${DATA_TO_UPLOAD} ${UPLOAD_URL}"
	eval $COMMAND

	# Writing the private key of configurator to a file to be used later when configurator is being created
	echo "${PRIVATEKEYOFCONFIGURATOR}" > ~/configkeys
fi


