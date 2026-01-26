#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "06-install-libraries.sh"

# Install MetaTrader5 library in Linux Python3 (not Wine Python)
# Flask app runs with Linux Python and connects to MT5 in Wine
log_message "INFO" "Installing MetaTrader5 library and dependencies in Linux Python3"
if ! is_python_package_installed "MetaTrader5"; then
    python3 -m pip install --no-cache-dir -r /app/requirements.txt
    log_message "INFO" "Python libraries installed successfully in Linux Python3."
else
    log_message "INFO" "MetaTrader5 library already installed in Linux Python3."
fi