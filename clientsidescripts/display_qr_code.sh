#!/bin/bash
#This script will display the existing QR code
#If no QR code is generated yet, the script will end after displaying a message
# Generating JPEG QR image
if [ -s ./qrcode.jpeg ]; then
	display qrcode.jpeg &
else
	echo "Cannot find a QR code image to display. Run the script to start supplicant and to generate QR code"
fi
