#!/bin/bash

# Debug log file
DEBUG_LOG="/var/log/fan-control-debug.log"

# Load configuration file
CONFIG_FILE="/opt/fan-control/ipmi_config.cfg"

echo "Starting fan-control script..." | tee -a $DEBUG_LOG

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found!" | tee -a $DEBUG_LOG
    exit 1
fi

echo "Loading configuration file..." | tee -a $DEBUG_LOG
source "$CONFIG_FILE"

# Construct the IPMI command with parameters from the config file
IPMI_COMMAND="ipmitool -I lanplus -H $IPMI_HOST -U $IPMI_USER -P $IPMI_PASSWORD -y $IPMI_YKEY"

# Load IPMI control script (ensure the path is correct)
echo "Running take-control.sh..." | tee -a $DEBUG_LOG
/opt/fan-control/take-control.sh >> $DEBUG_LOG 2>&1

# Function to keep logs for only 1 hour
manage_logs() {
    find $DEBUG_LOG -type f -mmin +60 -exec rm {} \;
}

# Start an infinite loop to check temperatures and adjust fan speed every 10 seconds
while true; do
    manage_logs

    echo "Checking temperatures..." | tee -a $DEBUG_LOG
    
    # Get GPU temperatures using nvidia-smi
    gpu_temp1=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 0 2>> $DEBUG_LOG)
    gpu_temp2=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 1 2>> $DEBUG_LOG)

    echo "GPU1 temp: $gpu_temp1, GPU2 temp: $gpu_temp2" | tee -a $DEBUG_LOG

    # Get CPU temperatures using the provided command for sensor IDs 0Eh and 0Fh
    cpu_temp1=$($IPMI_COMMAND sdr type temperature | grep '0Eh' | awk -F '|' '{print $5}' | awk '{print $1}' 2>> $DEBUG_LOG)
    cpu_temp2=$($IPMI_COMMAND sdr type temperature | grep '0Fh' | awk -F '|' '{print $5}' | awk '{print $1}' 2>> $DEBUG_LOG)

    echo "CPU0 temp: $cpu_temp1, CPU1 temp: $cpu_temp2" | tee -a $DEBUG_LOG

    # Determine the highest GPU temperature
    max_gpu_temp=$((gpu_temp1 > gpu_temp2 ? gpu_temp1 : gpu_temp2))

    echo "Max GPU temp: $max_gpu_temp" | tee -a $DEBUG_LOG

    # Determine the appropriate fan speed based on GPU temperature thresholds
    if [ "$max_gpu_temp" -lt 55 ]; then
        fan_speed=$VERY_LOW_FAN_SPEED
    elif [ "$max_gpu_temp" -lt 65 ]; then
        fan_speed=$LOW_FAN_SPEED
    elif [ "$max_gpu_temp" -lt 75 ]; then
        fan_speed=$MID_FAN_SPEED
    elif [ "$max_gpu_temp" -lt 85 ]; then
        fan_speed=$HIGH_FAN_SPEED
    else
        echo "ERROR: GPU temperature exceeded 85°C. Activating emergency override!" | systemd-cat -p err
        fan_speed=80
    fi

    # Cap fan speed at 65% unless in emergency override
    if [ "$fan_speed" -gt 65 ]; then
        fan_speed=65
    fi

    fan_speed_hex=$(printf '0x%02x' $fan_speed)

    echo "Setting fan speed to $fan_speed% (hex: $fan_speed_hex)" | tee -a $DEBUG_LOG

    # Apply the fan speed setting using remote IPMI command
    $IPMI_COMMAND raw 0x30 0x30 0x02 0xff "$fan_speed_hex" >> $DEBUG_LOG 2>&1

    # Error checking based on the temperature and fan speed
    if [ "$fan_speed" -eq "$LOW_FAN_SPEED" ] && [ "$max_gpu_temp" -gt 75 ]; then
        echo "ERROR: GPU temperature exceeded 75°C while fan speed was low ($fan_speed%)" | systemd-cat -p err | tee -a $DEBUG_LOG
    elif [ "$fan_speed" -eq "$MID_FAN_SPEED" ] && [ "$max_gpu_temp" -gt 85 ]; then
        echo "ERROR: GPU temperature exceeded 85°C while fan speed was mid ($fan_speed%)" | systemd-cat -p err | tee -a $DEBUG_LOG
    fi

    # Wait for 10 seconds before the next check
    sleep 10
done