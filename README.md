# Setup Manual for Wifi-Onboarding WPA3-DPP(using scripts)


# System requirements
1. Two test PC's with Ubuntu 17.10 installed, one acting as a Access Point(AP) and another as Client.
2. Two ALPHA AWUS036NHA wi-fi dongles, one configured as AP and another as client.

# Build configuration of AP

### 1. Build Steps

1. Install all dependencies for enabling hostapd in AP machine.

```
    gcc, make, build-essentials,libnl-3-dev,libnl-genl-3-dev,pkg-config,libssl-dev
```
2. Checkout the code from link given below.

```
     git clone -b DPP_Demo https://github.com/gladish/wpa3_tata.git .
```

3. Build procedure
```
     cd hostap/hostapd
     sudo make
 ```
4. Config files

    The config file for hostapd is present in the *configfile* folder. ie, hostap_dpp.conf

5. Static IP and DHCP Server.

    This step is not required for a successful 4-way handshake. However this static ip is required for accessing the server running in the AP
    for submitting scanned QR code and to upload the DPP keys data after AP self configuration
    It will be used to assign a static IP for AP. AP will also have a DHCP server to provide IP to any client being associated with it.
    Add the following to /etc/network/interfaces to have static IP.
```
     auto <wifi-interface>
     iface <wif-interface> inet static
     address 192.168.8.1
     netmask 255.255.255.0
```
This will provide static IP 192.168.8.1 for the interface. Install  *dnsmasq* in AP so it can act as DHCP server. Edit /etc/dnsmasq.conf

```
    interface=lo, <wifi-interface>
    no-dhcp-interface=lo
    dhcp-range=192.168.8.20,192.168.8.254,255.255.255.0,12h
```
Restart the network services
```
    sudo service networking restart
    sudo service network-manager restart
```
6. Passwordless sudo

    For running the hostapd cli activities, sudo permission is required. Setup a password less sudo account to perform those. Otherwise user  will be prompted to enter password in server console.

    Reference:
How to setup passowrd less sudo (https://serverfault.com/questions/160581/how-to-setup-passwordless-sudo-on-linux)

*Note: Enable ip forwarding and firewall rules if internet access is required for STA. This is an optional step*

### 2. Server setup

Run the below scripts to install all server dependencies and setup server (This is a one time activity)
```
./InstallScriptForAp.sh
```
### 3. Configuring AP as configurator and connecting to client

Run the below command using the hostapd_dpp.conf file along with path of hostapd .
```
./APsidescripts/get_config.sh <path/to/hostapd.conf> <path/of/root/hostap/>
```
example
```
    ./APsidescripts/get_config.sh ~/wpa3_tata/configfiles/hostap_dpp.conf ~/wpa3_tata/hostap
```
On running the above command the following are observed.

1. Server and hostapd are up and running.
2. A numbered list of available interfaces is displayed on the console, Select the hostapd interface from list by typing the corresponding number.
3. AP configures itself with dpp_connector, dpp_csign and dpp_netaccesskey, and these values are persisted even when AP is restarted.
4. Security method (DPP Connector, WPA-PSK and WPA-SAE ) for connection establishment is chosen via server.
5. The configured parameters are uploaded to the server. 



# Build configuration of STA

### 1. Build Steps

1. Install all dependencies for enabling hostapd.
```
    gcc, make, build-essentials,libnl-3-dev,libnl-genl-3-dev,pkg-config,libssl-dev
```
2. Checkout the code from link given below.

```
    git clone -b DPP_Demo https://github.com/gladish/wpa3_tata.git .
```

3. Build procedure
```
     cd hostap/wpa_supplicant
     sudo make
 ```
4. Config files

    The config file for supplicant is present in the  *configfile* folder. ie, wpa_supplicant_dpp.conf

5. Qr-Code dependencies setup

    Run the below script to setup qrcode dependencies(This is a one-time activity)
```
./InstallScriptForClient.sh
```

### 2. Configuring STA and getting connected (via scripts)

Run the below command in client machine.

```
    ./clientsidescripts/get_qr.sh <path/to/wpa_supplicant_dpp.conf> <path/of/root/hostap/>
```
example
```
    ./clientsidescripts/get_qr.sh ~/wpa3_tata/configfiles/wpa_supplicant_dpp.conf ~/wpa3_tata/hostap/
```
On running the above command the following are observed.

1. wpa_supplicant is up and running.
2. A numbered list of available interfaces is displayed on the console, Select the     wpa_supplicant interface from list by typing the corresponding number.
3.  Qrcode corresponding to the device is generated.
4.  wpa_supplicant starts listen mode, by listening to 2412 frequency.
5.  On receiving authentication request from configurator, client gets provisioned by configurator and get connected to the network on the fly and the provisioned values are persisted in *wpa_supplicant_dpp.conf* even when STA is restarted.

Scan the qrcode of client device via mobile app and provide it in the qrcode-submit web page (http://*ip of AP*:3000). The static IP address we have assigned above is *192.168.8.1*. On clicking 'submit' button in the web page, AP authenticates and provisions client with dpp_connector, dpp_csign, dpp_netaccesskey and connection is established on the fly between AP-STA.

### Verifying the connection
The successful 4-way handshake results in connection between AP and STA device. 
Now the AP and STA formed a LAN connection. 

