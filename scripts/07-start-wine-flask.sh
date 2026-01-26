#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "07-start-wine-flask.sh"

log_message "INFO" "Verifying MT5 is ready before starting Flask..."

# Verify MT5 is installed and running
MT5_FILE="/config/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
if [ ! -e "$MT5_FILE" ]; then
    MT5_FILE=$(find /config/.wine -name "terminal64.exe" 2>/dev/null | head -1)
fi

if [ -z "$MT5_FILE" ] || [ ! -e "$MT5_FILE" ]; then
    log_message "ERROR" "❌ MT5 is not installed! Cannot start Flask without MT5."
    exit 1
fi

# Check if MT5 process is running
if ! pgrep -f "terminal64.exe" > /dev/null; then
    log_message "WARN" "⚠️ MT5 terminal process not found. Starting it..."
    WINEARCH=win64 WINEPREFIX=/config/.wine wine "$MT5_FILE" > /tmp/mt5_terminal.log 2>&1 &
    sleep 10
    if ! pgrep -f "terminal64.exe" > /dev/null; then
        log_message "ERROR" "❌ Failed to start MT5 terminal. Cannot continue."
        exit 1
    fi
fi

log_message "INFO" "✅ MT5 verified and running"
log_message "INFO" "Starting Flask server with Linux Python3..."

# Flask app runs with Linux Python3 (not Wine Python)
# The MetaTrader5 library connects to MT5 terminal running in Wine
cd /app

# Verify Python and required libraries
log_message "INFO" "Verifying Python environment..."
if ! python3 -c "import flask" 2>/dev/null; then
    log_message "ERROR" "❌ Flask module not found!"
    exit 1
fi

if ! python3 -c "import MetaTrader5" 2>/dev/null; then
    log_message "ERROR" "❌ MetaTrader5 library not found! Cannot start Flask without it."
    exit 1
fi

log_message "INFO" "✅ All dependencies verified"

# Check if port is available
PORT=${MT5_API_PORT:-5001}
if netstat -tlnp 2>/dev/null | grep -q ":${PORT}" || ss -tlnp 2>/dev/null | grep -q ":${PORT}"; then
    log_message "WARN" "⚠️ Port ${PORT} is already in use!"
fi

# Start Flask and capture output
log_message "INFO" "Starting Flask application on port ${PORT}..."
cd /app
nohup python3 app.py > /tmp/flask_output.log 2>&1 &
FLASK_PID=$!

# Give the server some time to start
log_message "INFO" "Waiting for Flask to start (PID: $FLASK_PID)..."
sleep 12

# Check if the Flask server is running
if ps -p $FLASK_PID > /dev/null 2>&1; then
    log_message "INFO" "✅ Flask process is running (PID: $FLASK_PID)"
    # Verify it's actually listening
    sleep 3
    if netstat -tlnp 2>/dev/null | grep -q ":${PORT}" || ss -tlnp 2>/dev/null | grep -q ":${PORT}"; then
        log_message "INFO" "✅ Flask is listening on port ${PORT}"
        log_message "INFO" "Flask API available at http://0.0.0.0:${PORT}"
    else
        log_message "WARN" "⚠️ Flask process running but not listening on port ${PORT} yet"
        log_message "WARN" "Checking Flask output for errors..."
        tail -20 /tmp/flask_output.log >> /var/log/mt5_setup.log 2>&1 || true
    fi
else
    log_message "ERROR" "❌ Flask server failed to start (process died)."
    log_message "ERROR" "Flask output:"
    if [ -f /tmp/flask_output.log ]; then
        log_message "ERROR" "=== Flask Error Output ==="
        cat /tmp/flask_output.log >> /var/log/mt5_setup.log
        cat /tmp/flask_output.log
        log_message "ERROR" "=== End Flask Error Output ==="
    else
        log_message "ERROR" "No Flask output log found"
    fi
    log_message "INFO" "Attempting to start Flask in foreground to capture errors..."
    # Try to start it directly to see the error
    timeout 5 python3 app.py 2>&1 | head -30 || true
fi

# Keep container running
log_message "INFO" "Setup complete. Container will continue running."