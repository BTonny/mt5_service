#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "07-start-wine-flask.sh"

log_message "INFO" "Starting Flask server in Wine environment..."

# Get MT5_API_PORT from the init process environment (PID 1) which has docker-compose env vars
MT5_API_PORT=$(cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep '^MT5_API_PORT=' | cut -d'=' -f2)

if [ -z "$MT5_API_PORT" ]; then
    log_message "ERROR" "MT5_API_PORT environment variable is not set!"
    exit 1
fi

log_message "INFO" "MT5_API_PORT is set to: $MT5_API_PORT"

# Export it for Wine/Python
export MT5_API_PORT

# Run the Flask app using Wine's Python
wine python /app/app.py &

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