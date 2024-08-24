#!/bin/bash

# Script to reset the fan profiling 
echo "[!] Resetting Fan Profile to iDrac Control . . . "

# Load configuration file
CONFIG_FILE="./ipmi_config.cfg"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[!] Configuration file not found!"
    exit 1
fi

echo "[i] Loaded configuration file"

# Source the configuration file to import variables
source "$CONFIG_FILE"

ipmitool -I lanplus -H $IPMI_HOST -U $IPMI_USER -P $IPMI_PASSWORD -y $IPMI_YKEY raw 0x30 0x30 0x01 0x01

echo "[i] Fan Profile Reset to iDrac Control."