#!/bin/bash

# Debug log file
DEBUG_LOG="/var/log/fan-control-debug.log"

# Load configuration file
CONFIG_FILE="/opt/fan-control/ipmi_config.cfg"

echo "Starting fan-control script..." >> $DEBUG_LOG

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found!" >> $DEBUG_LOG
    exit 1
fi

echo "Loading configuration file..." >> $DEBUG_LOG
source "$CONFIG_FILE"

# Construct the IPMI command with parameters from the config file
IPMI_COMMAND="ipmitool -I lanplus -H $IPMI_HOST -U $IPMI_USER -P $IPMI_PASSWORD -y $IPMI_YKEY"

# Load IPMI control script (ensure the path is correct)
echo "Running take-control.sh..." >> $DEBUG_LOG
/opt/fan-control/take-control.sh >> $DEBUG_LOG 2>&1

# Start an infinite loop to check temperatures and adjust fan speed every 10 seconds
while true; do
    echo "Checking temperatures..." >> $DEBUG_LOG
    
    # Get GPU temperatures using nvidia-smi
    gpu_temp1=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 0 2>> $DEBUG_LOG)
    gpu_temp2=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 1 2>> $DEBUG_LOG)

    echo "GPU1 temp: $gpu_temp1, GPU2 temp: $gpu_temp2" >> $DEBUG_LOG

    # Get CPU temperatures using the provided command for sensor IDs 0Eh and 0Fh
    cpu_temp1=$($IPMI_COMMAND sdr type temperature | grep '0Eh' | awk -F '|' '{print $5}' | awk '{print $1}' 2>> $DEBUG_LOG)
    cpu_temp2=$($IPMI_COMMAND sdr type temperature | grep '0Fh' | awk -F '|' '{print $5}' | awk '{print $1}' 2>> $DEBUG_LOG)

    echo "CPU0 temp: $cpu_temp1, CPU1 temp: $cpu_temp2" >> $DEBUG_LOG

    # Determine the highest CPU temperature
    max_cpu_temp=$((cpu_temp1 > cpu_temp2 ? cpu_temp1 : cpu_temp2))
    max_gpu_temp=$((gpu_temp1 > gpu_temp2 ? gpu_temp1 : gpu_temp2))
    max_temp=$((max_cpu_temp > max_gpu_temp ? max_cpu_temp : max_gpu_temp))

    echo "Max temp: $max_temp" >> $DEBUG_LOG

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

    fan_speed_hex=$(printf '0x%02x' $fan_speed)

    echo "Setting fan speed to $fan_speed% (hex: $fan_speed_hex)" >> $DEBUG_LOG

    # Apply the fan speed setting using remote IPMI command
    $IPMI_COMMAND raw 0x30 0x30 0x02 0xff "$fan_speed_hex" >> $DEBUG_LOG 2>&1

    # Wait for 10 seconds before the next check
    sleep 10
done