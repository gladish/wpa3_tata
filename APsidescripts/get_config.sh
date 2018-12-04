#!/bin/bash
#script for AP-configurting itself
#run the script by running the below command
# ./get_config.sh <path/to/hostapd.conf> <path/of/hostapd/>

if [ $# -ne 2 ]; then
	echo "Invalid number of command line arguements."
	echo "Run in the format ./get_config.sh <path/to/hostapd.conf> <path/of/hostapd/>"
	exit 0
fi

echo "Killing key collection server, hostapd process if any running..."
#Kill existing process.
sudo pkill node
sudo pkill npm
sudo pkill hostapd
sudo airmon-ng check kill
sudo rm -rf /var/run/hostapd

echo "Killed server and hostapd"

UPLOAD_LOCATION="http://localhost:3000"
UPLOAD_URL="${UPLOAD_LOCATION}/storeddppcredentials"
DPP_LOGFILE=/tmp/LogFile
TOPDIR=$2
HOSTAPD_FOLDER=${TOPDIR}/hostapd/

#getting interface name and mac address
echo "Select the interface ID of AP"
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

#Run server
cd ../server; npm start $TOPDIR  &
cd -

echo "Started express node server at $UPLOAD_LOCATION to collect keys from AP"

#Remove any existing logs in the log file
sudo echo "Start" >$DPP_LOGFILE

echo "Stating hostapd process..."
#Run hostapd
sudo $HOSTAPD_FOLDER/hostapd -i$INTERFACE $1  | tee  $DPP_LOGFILE &

#hostapd_cli ping command will return "PONG" if hostapd is up
#If hostapd is not up, it will return error. So check for "PONG"
HOSTAPD_STATUS_CHECK_OUTPUT=$(sudo $HOSTAPD_FOLDER/hostapd_cli ping | grep -i PONG)
while [ "${HOSTAPD_STATUS_CHECK_OUTPUT}" != "PONG" ]
do
	echo "Hostapd not up. Waiting..."
	#Wait for a second and retry
	sleep 1
	HOSTAPD_STATUS_CHECK_OUTPUT=$(sudo $HOSTAPD_FOLDER/hostapd_cli ping |grep -i PONG)
done

echo "Started hostapd successfully"

CHECKDPPVALUES=$(grep -ic 'dpp_connector\|dpp_csign\|dpp_netaccesskey' $1)

echo "Checking whether DPP keys are already available in hostapd_dpp.conf file..."
if [ $CHECKDPPVALUES -eq 0 ]; then
	echo "No DPP keys are found, checking for configurator private key..."

	if [ -s ~/configkeys ]; then
		echo "Found configurator private key, creating configurator..."
		PRIVATEKEYOFCONFIGURATOR=`cat ~/configkeys`
		#The configurator is created with existing key
		sudo $HOSTAPD_FOLDER/hostapd_cli dpp_configurator_add key=$PRIVATEKEYOFCONFIGURATOR
		echo "Created configurator using the existing private key"

	else
		echo "Not found any configurator private key, creating configurator..."
		sudo $HOSTAPD_FOLDER/hostapd_cli dpp_configurator_add
		PRIVATEKEYOFCONFIGURATOR=$(sudo $HOSTAPD_FOLDER/hostapd_cli dpp_configurator_get_key 1 | grep -v 'Selected')
		echo "Created configurator using new private key"
	fi

	echo "Self configuration of AP..."
	sudo $HOSTAPD_FOLDER/hostapd_cli dpp_configurator_sign " configurator=1 conf=ap-dpp"

	#Wait for some time to complete the configuration process
	DPP_GREP_RESULT=$(grep -o "DPP-CONNECTOR.*"  $DPP_LOGFILE)
	while [ "$DPP_GREP_RESULT" = "" ]
	do
		#Wait for DPP configuration to be completed
		echo "Waiting for self configuration to be completed..."
		sleep 1
		DPP_GREP_RESULT=$(grep -o "DPP-CONNECTOR.*"  $DPP_LOGFILE)
	done
	echo "Self configuration of AP is completed"

	echo "Parsing DPP keys for persisting..."
	#By this time you should have the logs populated. Grep for connector,netaccess key and csign
	DPP_CONNECTOR=$(grep -o "DPP-CONNECTOR.*"  $DPP_LOGFILE)
	DPPCONNECTORPREFIX="DPP-CONNECTOR "
	DPP_CONNECTOR=${DPP_CONNECTOR#"$DPPCONNECTORPREFIX"}

	DPP_NETACCESSKEY=$(grep -o "DPP-NET-ACCESS-KEY.*"  $DPP_LOGFILE)
	DPPNETACCESSKEYPREFIX="DPP-NET-ACCESS-KEY "
	DPP_NETACCESSKEY=${DPP_NETACCESSKEY#"$DPPNETACCESSKEYPREFIX"}

	DPP_CSIGN=$(grep -o "DPP-C-SIGN-KEY.*"  $DPP_LOGFILE)
	DPPCSIGNPREFIXPREFIX="DPP-C-SIGN-KEY "
	DPP_CSIGN=${DPP_CSIGN#"$DPPCSIGNPREFIXPREFIX"}


	#Setting the dppconnectorvalue, dppcsignvalue and dppnetaccesskey at run time.
	sudo $HOSTAPD_FOLDER/hostapd_cli set "dpp_connector" ${DPP_CONNECTOR}
	sudo $HOSTAPD_FOLDER/hostapd_cli set "dpp_csign" ${DPP_CSIGN}
	sudo $HOSTAPD_FOLDER/hostapd_cli set "dpp_netaccesskey" ${DPP_NETACCESSKEY}
	echo "Self configuration values saved for runtime"

	# Writing dppconnectorvalue, dppcsignvalue, dppnetaccesskey to config file of AP. To persist after reboot
	echo "dpp_connector="${DPP_CONNECTOR}"" >> $1
	echo "dpp_csign="${DPP_CSIGN}"" >> $1
	echo "dpp_netaccesskey="${DPP_NETACCESSKEY}"" >> $1
	echo "Self configuration values saved to persistance"

	echo "Uploading keys to server at ${UPLOAD_LOCATION} ..."
	#Send the command to server
	DATA_TO_UPLOAD="'{\"dppconfigkey\":\"${PRIVATEKEYOFCONFIGURATOR}\",\"dppconnector\":\"${DPP_CONNECTOR}\",\"dppnetaccesskey\":\"${DPP_NETACCESSKEY}\",\"dppcsign\":\"${DPP_CSIGN}\", \"macaddress\":\"${MACADDRESS}\"}'"
	COMMAND="curl --header \"Content-Type: application/json\" --request POST --data ${DATA_TO_UPLOAD} ${UPLOAD_URL}"
	eval $COMMAND
	echo "Uploaded keys to server. Keys are available at ${UPLOAD_LOCATION}/getallconfig"

	# Writing the private key of configurator to a file to be used later when configurator is being created
	echo "${PRIVATEKEYOFCONFIGURATOR}" > ~/configkeys
	echo "Completed: AP is ready to connect to DPP clients"
fi


