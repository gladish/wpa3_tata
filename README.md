# Setup Manual for Wi-Fi Onboarding WPA3-DPP (using scripts)


### 1. System requirements

1.1  Two test PC's with Ubuntu 17.10 installed, one acting as a Access Point(AP)and another as Client.

1.2  Two ALFA AWUS036NHA Wi-Fi dongles, one configured as AP and another as client.

1.3  Android mobile phone with QR code scanning application

### 2. Setup AP

2.1 Checkout the code from link given below to AP dongle connected PC/PI.

```
     git clone -b DPP_Demo https://github.com/gladish/wpa3_tata.git .
```

2.2 Run the below scripts to install all the dependencies and setup server (This is a one time activity).

```
    ./InstallScriptForAp.sh
```

2.3 Static IP and DHCP Server.

The static ip is required for accessing the express node server running in the AP.
It will be used to assign a static IP for AP. AP will also have a DHCP server to provide IP to any client being associated with it.
Add the following to /etc/network/interfaces to have static IP.

``` 
     auto <Wi-Fi-interface>
     iface <Wi-Fi-interface> inet static
     address 192.168.8.1
     netmask 255.255.255.0
```

This will provide static IP 192.168.8.1 for the interface. Install  *dnsmasq* in AP so it can act as DHCP server. Edit /etc/dnsmasq.conf

```
    interface=lo, <Wi-Fi-interface>
    no-dhcp-interface=lo
    dhcp-range=192.168.8.20,192.168.8.254,255.255.255.0,12h
```
Restart the network services

```
    sudo service networking restart
    sudo service network-manager restart
```

2.4 Passwordless sudo

For running the hostapd cli activities, sudo permission is required. Setup a password less sudo account to perform those. Otherwise user  will beprompted to enter password in server console.

Reference: How to setup passowrd less sudo (https://serverfault.com/questions/160581/how-to-setup-passwordless-sudo-on-linux)

2.5 Building hostapd

```
     cd hostap/hostapd
     sudo make

 ```

### 3. Setup STA

3.1 Checkout the code from link given below to client dongle connected PC/PI.

```
    git clone -b DPP_Demo https://github.com/gladish/wpa3_tata.git .
```

3.2 Run the below script to install all dependencies(This is a one-time activity)

```
./InstallScriptForClient.sh

```

 3.3 Building wpa_supplicant

```
     cd hostap/wpa_supplicant
     sudo make
```

### 4.Runing AP

4.1 Location of config files

The config file for hostapd is present in the *configfile* folder.(hostapd_dpp.conf)

4.2 Run the below command using the hostapd_dpp.conf file along with path of hostapd.

```
    ./APsidescripts/get_config.sh <path/to/hostapd_dpp.conf> <path/of/hostap/>

```

example

```
    ./APsidescripts/get_config.sh ~/wpa3_tata/configfiles/hostapd_dpp.conf ~/wpa3_tata/hostap/ 

```
On running the above command the following actions will be taking place.

a. Express node server is enabled and is ready to accept configured keys. 

b. Hostapd is up and running.

c. A numbered list of available interfaces is displayed on the console, select the hostapd interface from list by typing the corresponding number.

d. AP configures itself with dpp_connector, dpp_csign and dpp_netaccesskey and these values are persisted in *hostapd_dpp.conf* file .

e. Any AP can upload the configuration to this express node server once AP is self configurated. Uploaded configuration parameters can be accessed using
*http://<ip of express node server>:3000/getallconfig*


### 5.Running STA

5.1 Location of config files

  The config file for wpa_supplicant is present in the  *configfile* folder.(wpa_supplicant_dpp.conf)

5.2 Run the below command in client machine.

```
    ./clientsidescripts/get_qr.sh <path/to/wpa_supplicant_dpp.conf> <path/of/hostap/>
```

example

```
    ./clientsidescripts/get_qr.sh ~/wpa3_tata/configfiles/wpa_supplicant_dpp.conf ~/wpa3_tata/hostap/
```

On running the above command the following actions will be taking place.

a. wpa_supplicant is up and running.

b. A numbered list of available interfaces is displayed on the console, select the wpa_supplicant interface from list by typing the corresponding number.

c. Qrcode corresponding to the device is generated. 

d. wpa_supplicant starts listen mode, by listening to 2412 frequency.


### 6. Connection Establishment

6.1 Connect the mobile phone to AP using WPA-PSK

6.2 Open the web page (http://*ip of AP*:3000) using browser in the mobile

6.3 Using QR code scanning application, scan the qrcode of the client device.

6.4 Submit the QR code to web page (http://*ip of AP*:3000). Please note that the static IP address assigned for AP is *192.168.8.1*.

6.5 Select a security method (DPP Connector, WPA-PSK and WPA-SAE ) from the list as shown in the webpage.

6.6 Click the 'submit' button in the web page, AP sends authentication request to client.

6.7 Once authentication is completed, client gets provisioned by configurator and get connected to the AP-network on the fly and the provisioned values are persisted in *wpa_supplicant_dpp.conf*.

### Verifying the connection
The successful 4-way handshake results in connection between AP and STA device. 
Now the AP and STA will be in a LAN connection with STA getting IP-address of 192.168.8.* (depending on IP range provideed in section 2.3). AP and STA should be able to ping each other now.

