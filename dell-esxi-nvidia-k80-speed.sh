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
IPMI_COMMAND="ipmitool -I lanplus -H $IPMI_HOST -U $IPMI_USER -P $IPMI_PASSWORD -y $IPMI_YKEY raw"

# Load IPMI control script (ensure the path is correct)
./take-control.sh

# Define temperature thresholds and corresponding fan speeds
very_low_temp_threshold=30
low_temp_threshold=40
mid_temp_threshold=60
high_temp_threshold=75
very_high_temp_threshold=85

very_low_fan_speed=20
low_fan_speed=30
mid_fan_speed=50
high_fan_speed=75
very_high_fan_speed=100

# Get GPU temperatures using nvidia-smi
gpu_temp1=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 0)
gpu_temp2=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 1)

# Determine the highest GPU temperature
max_temp=$((gpu_temp1 > gpu_temp2 ? gpu_temp1 : gpu_temp2))

# Determine the appropriate fan speed based on the GPU temperature
if [ "$max_temp" -lt "$very_low_temp_threshold" ]; then
    fan_speed=$very_low_fan_speed
elif [ "$max_temp" -lt "$low_temp_threshold" ]; then
    fan_speed=$low_fan_speed
elif [ "$max_temp" -lt "$mid_temp_threshold" ]; then
    fan_speed=$mid_fan_speed
elif [ "$max_temp" -lt "$high_temp_threshold" ]; then
    fan_speed=$high_fan_speed
else
    fan_speed=$very_high_fan_speed
fi

# Convert the fan speed percentage to hexadecimal format
fan_speed_hex=$(printf '0x%02x' $fan_speed)

# Debug output
echo "GPU Temperatures: GPU 0 = $gpu_temp1°C, GPU 1 = $gpu_temp2°C"
echo "Max GPU Temperature: $max_temp°C"
echo "Setting fan speed to $fan_speed% (hex: $fan_speed_hex)"

# Apply the fan speed setting using remote IPMI command
$IPMI_COMMAND 0x30 0x30 0x02 0xff "$fan_speed_hex"

# Confirmation message
echo "Fan speed set to $fan_speed% based on GPU temperatures."