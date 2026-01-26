#!/bin/bash

# Source common variables and functions
source /scripts/02-common.sh

log_message "INFO" "=== Starting MT5 Service Setup ==="
log_message "INFO" "This process will take 5-15 minutes. Progress will be logged here."

# Run installation scripts - MT5 MUST succeed
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_message "INFO" "Step 1/5: Installing Mono..."
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
/scripts/03-install-mono.sh
if [ $? -ne 0 ]; then
    log_message "ERROR" "❌ Mono installation failed. Cannot continue."
    exit 1
fi

log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_message "INFO" "Step 2/5: Installing MT5 (this will take 5-10 minutes)..."
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
/scripts/04-install-mt5.sh
if [ $? -ne 0 ]; then
    log_message "ERROR" "❌ MT5 installation failed. Cannot continue without MT5."
    exit 1
fi

log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_message "INFO" "Step 3/5: Installing Python..."
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
/scripts/05-install-python.sh
if [ $? -ne 0 ]; then
    log_message "ERROR" "❌ Python installation failed. Cannot continue."
    exit 1
fi

log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_message "INFO" "Step 4/5: Installing Python libraries..."
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
/scripts/06-install-libraries.sh
if [ $? -ne 0 ]; then
    log_message "ERROR" "❌ Library installation failed. Cannot continue."
    exit 1
fi

log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_message "INFO" "Step 5/5: Starting Flask API..."
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
/scripts/07-start-wine-flask.sh
if [ $? -ne 0 ]; then
    log_message "ERROR" "❌ Flask startup failed."
    exit 1
fi

log_message "INFO" "=== Setup Complete ==="
log_message "INFO" "Container will continue running. Check logs for status."

# Keep the script running
tail -f /dev/null