#!/bin/bash

# Fix Wine prefix ownership (in case volume has wrong permissions)
chown -R abc:abc /config/.wine 2>/dev/null || true
chmod -R 755 /config/.wine 2>/dev/null || true

# Run the startup script as abc user to avoid Wine ownership issues
runuser -u abc -- /bin/bash << 'EOF'
# Source common variables and functions
source /scripts/02-common.sh

# Run installation scripts
/scripts/03-install-mono.sh
/scripts/04-install-mt5.sh
/scripts/05-install-python.sh
/scripts/06-install-libraries.sh

# Start servers
/scripts/07-start-wine-flask.sh
EOF

# Keep the script running
tail -f /dev/null