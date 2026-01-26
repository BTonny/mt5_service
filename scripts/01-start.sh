#!/bin/bash

# Source common variables and functions
source /scripts/02-common.sh

log_message "INFO" "=== Starting MT5 Service Setup ==="

# Run installation scripts (continue even if some fail)
log_message "INFO" "Step 1/5: Installing Mono..."
/scripts/03-install-mono.sh || log_message "WARN" "Mono installation had issues, continuing..."

log_message "INFO" "Step 2/5: Installing MT5 (may take a few minutes)..."
/scripts/04-install-mt5.sh || log_message "WARN" "MT5 installation had issues, continuing..."

log_message "INFO" "Step 3/5: Installing Python..."
/scripts/05-install-python.sh || log_message "WARN" "Python installation had issues, continuing..."

log_message "INFO" "Step 4/5: Installing Python libraries..."
/scripts/06-install-libraries.sh || log_message "WARN" "Library installation had issues, continuing..."

log_message "INFO" "Step 5/5: Starting Flask API..."
/scripts/07-start-wine-flask.sh || log_message "ERROR" "Flask startup had issues"

log_message "INFO" "=== Setup Complete ==="
log_message "INFO" "Container will continue running. Check logs for status."

# Keep the script running
tail -f /dev/null