#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "06-install-libraries.sh"

# Install Python libraries in Linux Python3 (not Wine Python)
# Flask app runs with Linux Python and connects to MT5 in Wine
log_message "INFO" "Installing Python libraries in Linux Python3"

# Install core dependencies first (Flask, etc.) - these are critical
log_message "INFO" "Installing core dependencies (Flask, pandas, numpy, etc.)..."
python3 -m pip install --no-cache-dir flask pandas==1.4.2 numpy==1.22.4 pytz python-dotenv flasgger python-json-logger 2>&1 | tee -a /var/log/mt5_setup.log

if [ $? -eq 0 ]; then
    log_message "INFO" "✅ Core Python libraries installed successfully."
else
    log_message "ERROR" "❌ Failed to install core Python libraries."
    exit 1
fi

# Try to install MetaTrader5 (may fail if MT5 terminal not running, but that's OK)
log_message "INFO" "Attempting to install MetaTrader5 library..."
python3 -m pip install --no-cache-dir MetaTrader5 2>&1 | tee -a /var/log/mt5_setup.log

if [ $? -eq 0 ]; then
    log_message "INFO" "✅ MetaTrader5 library installed successfully."
else
    log_message "WARN" "⚠️ MetaTrader5 library installation failed (this is OK - will install after MT5 is running)."
    log_message "INFO" "Flask API will start but MT5 features will be unavailable until MT5 terminal is running."
fi

log_message "INFO" "Python library installation complete."