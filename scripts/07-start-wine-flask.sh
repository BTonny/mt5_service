#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "07-start-wine-flask.sh"

log_message "INFO" "Starting Flask server with Linux Python3..."

# Flask app runs with Linux Python3 (not Wine Python)
# The MetaTrader5 library connects to MT5 terminal running in Wine
cd /app
python3 app.py &

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