#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "07-start-wine-flask.sh"

log_message "INFO" "Starting Flask server in Wine environment..."

# Try multiple methods to get MT5_API_PORT
# Method 1: Check current process environment
if [ -z "$MT5_API_PORT" ]; then
    # Method 2: Read from init process (PID 1)
    MT5_API_PORT=$(cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep '^MT5_API_PORT=' | cut -d'=' -f2)
fi

if [ -z "$MT5_API_PORT" ]; then
    # Method 3: Read from any process that has it (check a few PIDs)
    for pid in 1 $(pgrep -f "s6-svscan\|init" | head -1); do
        if [ -n "$pid" ] && [ -r "/proc/$pid/environ" ]; then
            MT5_API_PORT=$(cat /proc/$pid/environ 2>/dev/null | tr '\0' '\n' | grep '^MT5_API_PORT=' | cut -d'=' -f2)
            [ -n "$MT5_API_PORT" ] && break
        fi
    done
fi

if [ -z "$MT5_API_PORT" ]; then
    # Method 4: Try to read from .env file if mounted (fallback)
    if [ -f "/config/.env" ]; then
        MT5_API_PORT=$(grep '^MT5_API_PORT=' /config/.env 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi
fi

if [ -z "$MT5_API_PORT" ]; then
    # Debug: Show what we can see
    log_message "DEBUG" "Checking /proc/1/environ for MT5_API_PORT..."
    cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep -i mt5 || log_message "DEBUG" "No MT5_* variables found in /proc/1/environ"
    log_message "DEBUG" "Current process environment:"
    env | grep -i mt5 || log_message "DEBUG" "No MT5_* variables in current env"
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