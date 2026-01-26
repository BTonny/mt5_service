#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "07-start-wine-flask.sh"

log_message "INFO" "Starting Flask server in Wine environment..."

# Debug: Log environment variable status
if [ -z "$MT5_API_PORT" ]; then
    log_message "ERROR" "MT5_API_PORT environment variable is not set!"
    log_message "DEBUG" "Available environment variables:"
    env | grep -i mt5 || log_message "DEBUG" "No MT5_* variables found"
    exit 1
else
    log_message "INFO" "MT5_API_PORT is set to: $MT5_API_PORT"
fi

# Run the Flask app using Wine's Python
# Explicitly pass environment variables to Wine to ensure they're available to Python
MT5_API_PORT="$MT5_API_PORT" wine python /app/app.py &

FLASK_PID=$!

# Give the server some time to start
sleep 5

# Check if the Flask server is running
if ps -p $FLASK_PID > /dev/null; then
    log_message "INFO" "Flask server in Wine started successfully with PID $FLASK_PID."
else
    log_message "ERROR" "Failed to start Flask server in Wine."
    exit 1
fi