#!/bin/bash

# Fix Wine prefix ownership (in case volume has wrong permissions) - only if running as root
if [ "$(id -u)" -eq 0 ]; then
    chown -R abc:abc /config/.wine 2>/dev/null || true
    chmod -R 755 /config/.wine 2>/dev/null || true
    # Run as abc user, preserving environment variables
    # runuser without -l preserves the current environment
    exec runuser -u abc -- "$0" "$@"
    exit 0
fi

# From here, we're running as abc user
# Source common variables and functions
source /scripts/02-common.sh

# Run installation scripts
/scripts/03-install-mono.sh
/scripts/04-install-mt5.sh
/scripts/05-install-python.sh
/scripts/06-install-libraries.sh

# Start servers
/scripts/07-start-wine-flask.sh

# Keep the script running
tail -f /dev/null