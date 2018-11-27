# WPA3 enabled for both supplicant and hostapd

DPP, SAE, OWE enabled for hostapd and supplicant. The readme focuses on **Device provisioning Protocol (DPP)**

# Setting up the code

### Set up Environment.
Connect 2 Alfa AWUS036NHA devices in two PC. One will act as AP and other as STA. 

### Dependencies for enabling hostapd and wpa-supplicant.

```gcc, make, build-essentials,libnl-3-dev,libnl-genl-3-dev,pkg-config,libssl-dev```

### Checkout the code.
``` git clone -b WPA3_Enabled_Hostapd https://github.com/gladish/wpa3_tata.git ```

### Build procedure
```
   cd hostap/hostapd
   sudo make
   cd hostap/wpa_supplicant
   sudo make
 ```

### Config files

The config file for hostap and supplicant are present in the *configfile* folder. ie, hostap_dpp.conf and wpa_supplicant_dpp.conf

### Static IP and DHCP Server (Optional)
This step is not required for a successful 4-way handshake.
This is an optional step. It will be used to assign a static IP for AP. AP will also have a DHCP server to provide IP to any client being associated with it. 
Add following to /etc/network/interfaces to have static IP. 
```
auto <wifi-interface>
iface <wif-interface> inet static
address 192.168.8.1
netmask 255.255.255.0
```
This will provide static IP 192.168.8.1 for the interface. Install *dnsmasq* in AP so it can act as DHCP server. Edit /etc/dnsmasq.conf
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
### Configuring AP as configurator

AP needs to get configured with DPP configurations and act as a configurator. 
Steps involved

1) Update the interface name in the hostap_dpp.conf. Use ```ifconfig``` to get the wireless network interface name. 

2) Run hostapd 
    ```
    cd hostap/hostapd
    sudo ./hostapd ~/wpa3_tata/configfiles/hostap_dpp.conf
    ```
    
3) Add a configurator. Open a separate terminal for executing hostap_cli
    ```
    cd hostap/hostapd
    sudo ./hostapd_cli dpp_configurator_add
    ```
    On successful addition of configurator it's ID is returned.
    
4) Note the private key of configurator. It is used to create same configurator if a reboot is performed. 
    ```sudo ./hostapd_cli dpp_configurator_get_key <configurator-id>```
    
5) Get AP self configured
    ```sudo ./hostapd_cli dpp_configurator_sign " conf=ap-dpp configurator=<configurator-id>"```
    On executing the command the DPP values are printed on hostapd console
    
6) Set those values to the run time instance. 
    ```
    sudo ./hostapd_cli set dpp_connector <connector-value-printed-on-console>
    sudo ./hostapd_cli set dpp_csign <csign-value-printed-on-console>
    sudo ./hostapd_cli set dpp_netaccesskey <net-accesskey-printed-on-console>
     ```
    If a reboot happens these values won't be persisted. To persist copy the following values to the config file *hostap_dpp.conf*
    ```
    dpp_connector=<connector-value-printed-on-console>
    dpp_csign=<csign-value-printed-on-console>
    dpp_netaccesskey=<net-accesskey-printed-on-console>
    ```
     If reboot is performed then the new configurator have to be created with the key obtained in step 4. The command to recreate the same configurator on hostapd is 
     ```sudo ./hostapd_cli dpp_configurator_add key=<key-of-configurator-noted-down>```
     
Now we have a fully configured AP.

### Configuring STA and getting connected

Start wpa_supplicant in other machine and generate QR code and make STA in listen mode to be provisioned by configurator and get connected to the network.

1) Run wpa_supplicant in another machine
    ```
    cd hostap/wpa_supplicant
    sudo ./wpa_supplicant -Dnl80211 -i<interfacename> -c ~/wpa3_tata/configfiles/wpa_supplicant_dpp.conf 
    ```
    
2) Generate QR code of client. Open a separate terminal for executing wpa_cli
    ``` sudo ./wpa_cli dpp_bootstrap_gen type=qrcode mac=<mac-address-of-client> chan=81/1```
    
3) Get QR code of client
    ``` sudo ./wpa_cli dpp_bootstrap_get_uri <qr-code-id>```
    
4) Make client listen to DPP request (The central frequncy of channel 1 is 2412)
    ```sudo ./wpa_cli dpp_listen 2412 ```
    
5) Enter the QR code in the hostapd running in the other machine
    ```sudo ./hostapd_cli dpp_qr_code "<qr-code-of-client>"```
    On successfully adding QR code, an ID is returned. 
    
6) Send authentication request from hostapd. On sending authentication request the SSID information should be send in hex-encoded format. In the command given below, the SSID used is WPA3WIFI. The hex-encoded value of WPA3WIFI is used in the below command. For other SSID provide the corresponding hexvalue.
    ```sudo ./hostapd_cli dpp_auth_init peer=<qr-code-id> conf=sta-dpp configurator=<configurator-id> ssid=5750413357494649```
    
    Now the wpa_supplicant console will have the dpp configuration. Since the supplicant config file have `dpp_config_processing=2` these values are taken on fly and connected to the AP.
    
7) Storing DPP credentials on the STA config file *wpa_supplicant_dpp.conf* . This is to keep the values persist across reboots. These values can be saved to the config file of supplicant using the following command. Note down the network id on the wpa supplicant console before executing the command.
    ```sudo ./wpa_cli save_config <network-id>```


    




