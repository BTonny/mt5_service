#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "07-start-wine-flask.sh"

log_message "INFO" "Starting Flask server with Linux Python3..."

# Flask app runs with Linux Python3 (not Wine Python)
# The MetaTrader5 library connects to MT5 terminal running in Wine
cd /app

# Start Flask and capture output
python3 app.py > /tmp/flask_output.log 2>&1 &
FLASK_PID=$!

# Give the server some time to start
sleep 8

# Check if the Flask server is running
if ps -p $FLASK_PID > /dev/null 2>&1; then
    log_message "INFO" "✅ Flask server started successfully with PID $FLASK_PID."
    log_message "INFO" "Flask API available on port 5001"
else
    log_message "ERROR" "❌ Flask server failed to start."
    log_message "ERROR" "Flask output:"
    cat /tmp/flask_output.log >> /var/log/mt5_setup.log
    log_message "ERROR" "Check /tmp/flask_output.log for details"
    # Don't exit - let the container keep running so we can debug
    # The app might still work even if MT5 isn't available
fi

# Keep container running (01-start.sh already has tail -f /dev/null, but this ensures it)
sleep infinity