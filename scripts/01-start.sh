#!/bin/bash

# Source common variables and functions
source /scripts/02-common.sh

# Fix Wine prefix ownership (in case volume has wrong permissions)
log_message "INFO" "Fixing Wine prefix ownership..."
chown -R abc:abc /config/.wine 2>/dev/null || true
chmod -R 755 /config/.wine 2>/dev/null || true

# Run installation scripts
/scripts/03-install-mono.sh
/scripts/04-install-mt5.sh
/scripts/05-install-python.sh
/scripts/06-install-libraries.sh

# Start servers
/scripts/07-start-wine-flask.sh

# Keep the script running
tail -f /dev/null