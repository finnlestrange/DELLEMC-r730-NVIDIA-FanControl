#!/bin/bash

# Load configuration file
CONFIG_FILE="/opt/fan-control/ipmi_config.cfg"

# Check if the configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found at $CONFIG_FILE. Please ensure ipmi_config.cfg is present."
    exit 1
fi

# Source the configuration file to import variables
source "$CONFIG_FILE"

# Construct the IPMI command with parameters from the config file
IPMI_COMMAND="ipmitool -I lanplus -H $IPMI_HOST -U $IPMI_USER -P $IPMI_PASSWORD -y $IPMI_YKEY"

# Get GPU temperatures using nvidia-smi
gpu_temp1=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 0 2>/dev/null)
gpu_temp2=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 1 2>/dev/null)

# Get CPU temperatures using the provided command for sensor IDs 0Eh and 0Fh
cpu_temp1=$($IPMI_COMMAND sdr type temperature | grep '0Eh' | awk -F '|' '{print $5}' | awk '{print $1}')
cpu_temp2=$($IPMI_COMMAND sdr type temperature | grep '0Fh' | awk -F '|' '{print $5}' | awk '{print $1}')


# Display the formatted information
echo "==============================="
echo "System Temperature"
echo "==============================="
echo "GPU 0 Temperature: ${gpu_temp1}°C"
echo "GPU 1 Temperature: ${gpu_temp2}°C"
echo "CPU 0 Temperature: ${cpu_temp1}°C"
echo "CPU 1 Temperature: ${cpu_temp2}°C"
echo "-------------------------------"