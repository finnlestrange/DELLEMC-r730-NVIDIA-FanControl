#!/bin/bash

# Define variables
SERVICE_NAME="fan-control"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
OPT_PATH="/opt/fan-control"
SCRIPT_PATH="/opt/fan-control/fan-control.sh"
RESET_SCRIPT="reset.sh"
RESET_SCRIPT_PATH="/opt/fan-control/${RESET_SCRIPT}"
TAKE_CONTROL_SCRIPT="take-control.sh"
SOURCE_SCRIPT="fan-control.sh"  # The fan-control.sh should be in the same directory as setup-service.sh
SOURCE_RESET_SCRIPT="reset.sh"  # The reset script should be in the same directory as setup-service.sh
SOURCE_TAKE_CONTROL_SCRIPT="take-control.sh"  # The take-control script should be in the same directory as setup-service.sh
CONFIG_FILE_PATH="/opt/fan-control/ipmi_config.cfg"

# Ensure the script is run as sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

# Create the target directory if it doesn't exist
echo "Creating target directory /opt/fan-control if it doesn't exist..."
mkdir -p /opt/fan-control

# Copy the fan-control.sh script to the correct location
echo "Copying $SOURCE_SCRIPT to $SCRIPT_PATH..."
cp "$SOURCE_SCRIPT" "$SCRIPT_PATH"

# Copy the take-control.sh script to the correct location
echo "Copying $SOURCE_TAKE_CONTROL_SCRIPT to $OPT_PATH..."
cp "$SOURCE_TAKE_CONTROL_SCRIPT" "$OPT_PATH"

# Copy the reset script to the correct location
echo "Copying $SOURCE_RESET_SCRIPT to $RESET_SCRIPT_PATH..."
cp "$SOURCE_RESET_SCRIPT" "$RESET_SCRIPT_PATH"

# Set the correct permissions for the scripts
echo "Setting executable permissions for $SCRIPT_PATH, $RESET_SCRIPT_PATH, and $SOURCE_TAKE_CONTROL_SCRIPT..."
chmod +x "$SCRIPT_PATH"
chmod +x "$RESET_SCRIPT_PATH"
chmod +x "$OPT_PATH/$SOURCE_TAKE_CONTROL_SCRIPT"

# Ensure the configuration file exists
if [ ! -f "$CONFIG_FILE_PATH" ]; then
    echo "Configuration file not found at $CONFIG_FILE_PATH. Please ensure ipmi_config.cfg is present."
    exit 1
fi

# Create the systemd service file
echo "Creating systemd service file at $SERVICE_FILE..."
cat <<EOL | sudo tee $SERVICE_FILE > /dev/null
[Unit]
Description=Fan Control Service
After=network.target

[Service]
Type=simple
ExecStart=$SCRIPT_PATH
ExecStop=$RESET_SCRIPT_PATH
Restart=on-failure
RestartSec=10
StandardOutput=append:/var/log/${SERVICE_NAME}.log
StandardError=append:/var/log/${SERVICE_NAME}.log

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd manager configuration
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable the service to start on boot
echo "Enabling $SERVICE_NAME service to start on boot..."
systemctl enable ${SERVICE_NAME}.service

# Start the service
echo "Starting $SERVICE_NAME service..."
systemctl start ${SERVICE_NAME}.service

# Final confirmation
echo "Service ${SERVICE_NAME} has been set up and started successfully."
echo "You can check the service status with: sudo systemctl status ${SERVICE_NAME}.service"