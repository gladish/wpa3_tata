#!/bin/sh
sudo apt-get install  gcc make build-essentials libnl-3-dev libnl-genl-3-dev pkg-config libssl-dev
sudo apt-get install mongodb
sudo apt-get install nodejs
sudo apt-get install npm
sudo apt-get install jq
sudo apt-get install curl
sudo apt-get install aircrack-ng
cd server; npm install
chmod +x scripts/*.sh
cd -

