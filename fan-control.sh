#!/bin/bash

# Load configuration file
CONFIG_FILE="./ipmi_config.cfg"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found!"
    exit 1
fi

# Source the configuration file to import variables
source "$CONFIG_FILE"

# Construct the IPMI command with parameters from the config file
IPMI_COMMAND="ipmitool -I lanplus -H $IPMI_HOST -U $IPMI_USER -P $IPMI_PASSWORD -y $IPMI_YKEY"

# Load IPMI control script (ensure the path is correct)
./take-control.sh

# Start an infinite loop to check temperatures and adjust fan speed every 10 seconds
while true; do

    # Get GPU temperatures using nvidia-smi
    gpu_temp1=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 0)
    gpu_temp2=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 1)

    # Get CPU temperatures using the provided command for sensor IDs 0Eh and 0Fh
    cpu_temp1=$($IPMI_COMMAND sdr type temperature | grep '0Eh' | awk -F '|' '{print $5}' | awk '{print $1}')
    cpu_temp2=$($IPMI_COMMAND sdr type temperature | grep '0Fh' | awk -F '|' '{print $5}' | awk '{print $1}')

    # Determine the highest CPU temperature
    max_cpu_temp=$((cpu_temp1 > cpu_temp2 ? cpu_temp1 : cpu_temp2))

    # Determine the highest GPU temperature
    max_gpu_temp=$((gpu_temp1 > gpu_temp2 ? gpu_temp1 : gpu_temp2))

    # Determine the max temperature between CPU and GPU
    max_temp=$((max_cpu_temp > max_gpu_temp ? max_cpu_temp : max_gpu_temp))

    # Determine the appropriate fan speed based on the highest temperature
    if [ "$max_temp" -lt "$VERY_LOW_TEMP_THRESHOLD" ]; then
        fan_speed=$VERY_LOW_FAN_SPEED
    elif [ "$max_temp" -lt "$LOW_TEMP_THRESHOLD" ]; then
        fan_speed=$LOW_FAN_SPEED
    elif [ "$max_temp" -lt "$MID_TEMP_THRESHOLD" ]; then
        fan_speed=$MID_FAN_SPEED
    elif [ "$max_temp" -lt "$HIGH_TEMP_THRESHOLD" ]; then
        fan_speed=$HIGH_FAN_SPEED
    else
        fan_speed=$VERY_HIGH_FAN_SPEED
    fi

    # Convert the fan speed percentage to hexadecimal format
    fan_speed_hex=$(printf '0x%02x' $fan_speed)

    # Debug output
    echo "GPU Temperatures: GPU 1 = $gpu_temp1°C, GPU 2 = $gpu_temp2°C"
    echo "CPU Temperatures: CPU 0 = $cpu_temp1°C, CPU 1 = $cpu_temp2°C"
    echo "Max Temperature: $max_temp°C"
    echo "Setting fan speed to $fan_speed% (hex: $fan_speed_hex)"

    # Apply the fan speed setting using remote IPMI command
    $IPMI_COMMAND raw 0x30 0x30 0x02 0xff "$fan_speed_hex"

    # Confirmation message
    echo "Fan speed set to $fan_speed% based on CPU and GPU temperatures."

    # Wait for 10 seconds before the next check
    sleep 10

done