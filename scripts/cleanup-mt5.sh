#!/bin/bash

# Cleanup script for MT5 installation artifacts
# Usage: docker exec mt5 /scripts/cleanup-mt5.sh

source /scripts/02-common.sh

log_message "INFO" "=== MT5 Cleanup Script ==="

# Check disk usage before cleanup
BEFORE=$(df -h /config | tail -1 | awk '{print $3}')
log_message "INFO" "Disk usage before cleanup: $BEFORE"

# Remove partial MT5 installations
log_message "INFO" "Removing partial MT5 installations..."
rm -rf "/config/.wine/drive_c/Program Files/MetaTrader 5" 2>/dev/null || true
rm -rf "/config/.wine/drive_c/Program Files (x86)/MetaTrader 5" 2>/dev/null || true

# Clean up installer files
log_message "INFO" "Removing installer files..."
rm -f /tmp/mt5setup.exe /tmp/mt5_installer.log 2>/dev/null || true

# Clean up Wine temp files
log_message "INFO" "Cleaning Wine temp files..."
find /config/.wine -name "*.tmp" -type f -delete 2>/dev/null || true
find /config/.wine -name "*.log" -type f -delete 2>/dev/null || true

# Clean up Wine cache (be careful with this)
log_message "INFO" "Cleaning Wine cache..."
rm -rf /config/.wine/drive_c/windows/temp/* 2>/dev/null || true
rm -rf /config/.wine/drive_c/users/*/Temp/* 2>/dev/null || true
rm -rf /config/.wine/drive_c/users/*/AppData/Local/Temp/* 2>/dev/null || true

# Check disk usage after cleanup
AFTER=$(df -h /config | tail -1 | awk '{print $3}')
log_message "INFO" "Disk usage after cleanup: $AFTER"
log_message "INFO" "=== Cleanup Complete ==="
