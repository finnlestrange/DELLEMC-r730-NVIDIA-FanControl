#!/bin/bash

# Load configuration file
CONFIG_FILE="/opt/fan-control/ipmi_config.cfg"

# Source the configuration file to import variables
source "$CONFIG_FILE"

# Construct the IPMI command with parameters from the config file
IPMI_COMMAND="ipmitool -I lanplus -H $IPMI_HOST -U $IPMI_USER -P $IPMI_PASSWORD -y $IPMI_YKEY"

# Reset fan control to automatic (example command)
$IPMI_COMMAND raw 0x30 0x30 0x01 0x01

echo "Fan control has been reset to automatic."