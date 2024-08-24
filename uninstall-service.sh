#!/bin/bash

# Define variables
SERVICE_NAME="fan-control"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
OPT_PATH="/opt/fan-control"
LOG_FILE="/var/log/${SERVICE_NAME}.log"

# Ensure the script is run as sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

# Stop the service if it's running
echo "Stopping $SERVICE_NAME service if it is running..."
systemctl stop ${SERVICE_NAME}.service

# Disable the service to prevent it from starting on boot
echo "Disabling $SERVICE_NAME service..."
systemctl disable ${SERVICE_NAME}.service

# Remove the systemd service file
echo "Removing systemd service file at $SERVICE_FILE..."
rm -f $SERVICE_FILE

# Reload systemd manager configuration
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Remove the log file if it exists
if [ -f "$LOG_FILE" ]; then
    echo "Removing log file at $LOG_FILE..."
    rm -f $LOG_FILE
fi

# Remove the /opt/fan-control directory and all its contents
if [ -d "$OPT_PATH" ]; then
    echo "Removing $OPT_PATH directory and all its contents..."
    rm -rf $OPT_PATH
fi

# Final confirmation
echo "Service ${SERVICE_NAME} has been successfully uninstalled."