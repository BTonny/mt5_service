#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "03-install-mono.sh"

# CRITICAL: Ensure WINEARCH is set to win64 before any Wine operations
export WINEARCH=win64
export WINEPREFIX=/config/.wine

# Remove any existing Wine prefix to ensure clean 64-bit initialization
if [ -d "/config/.wine" ]; then
    log_message "INFO" "Removing existing Wine prefix for clean 64-bit initialization..."
    rm -rf /config/.wine
    sleep 1
fi

# Initialize Wine as 64-bit with explicit environment
log_message "INFO" "Initializing Wine as 64-bit (WINEARCH=win64)..."

# Try to find wine64 binary first, fallback to wine
if command -v wine64 >/dev/null 2>&1; then
    log_message "INFO" "Using wine64 binary for 64-bit initialization..."
    WINEARCH=win64 WINEPREFIX=/config/.wine wine64 wineboot --init 2>&1 | tee -a /var/log/mt5_setup.log
else
    log_message "INFO" "Using wine binary with WINEARCH=win64..."
    WINEARCH=win64 WINEPREFIX=/config/.wine wineboot --init 2>&1 | tee -a /var/log/mt5_setup.log
fi

# Wait for Wine to fully initialize
sleep 3

# Verify Wine architecture
if [ -f "/config/.wine/system.reg" ]; then
    ARCH=$(grep "^#arch" /config/.wine/system.reg | head -1)
    log_message "INFO" "Wine architecture: $ARCH"
    if echo "$ARCH" | grep -q "win64"; then
        log_message "INFO" "✅ Wine initialized successfully as 64-bit!"
    else
        log_message "ERROR" "❌ Wine initialized as 32-bit. This will cause MT5 installation to fail."
        log_message "ERROR" "Attempting to fix by removing and reinitializing..."
        rm -rf /config/.wine
        sleep 1
        if command -v wine64 >/dev/null 2>&1; then
            WINEARCH=win64 WINEPREFIX=/config/.wine wine64 wineboot --init 2>&1 | tee -a /var/log/mt5_setup.log
        else
            WINEARCH=win64 WINEPREFIX=/config/.wine /usr/bin/wineboot --init 2>&1 | tee -a /var/log/mt5_setup.log
        fi
        sleep 3
        if [ -f "/config/.wine/system.reg" ] && grep -q "#arch.*win64" /config/.wine/system.reg; then
            log_message "INFO" "✅ Wine fixed - now 64-bit!"
        else
            log_message "ERROR" "❌ Failed to initialize Wine as 64-bit. MT5 will not work."
        fi
    fi
else
    log_message "ERROR" "Wine system.reg not found after initialization."
fi

# Install Mono if not present
if [ ! -e "/config/.wine/drive_c/windows/mono" ]; then
    log_message "INFO" "Downloading and installing Mono..."
    wget -O /tmp/mono.msi https://dl.winehq.org/wine/wine-mono/8.0.0/wine-mono-8.0.0-x86.msi > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        WINEDLLOVERRIDES=mscoree=d WINEARCH=win64 WINEPREFIX=/config/.wine wine msiexec /i /tmp/mono.msi /qn
        if [ $? -eq 0 ]; then
            log_message "INFO" "Mono installed successfully."
        else
            log_message "ERROR" "Failed to install Mono."
        fi
        rm -f /tmp/mono.msi
    else
        log_message "ERROR" "Failed to download Mono installer."
    fi
else
    log_message "INFO" "Mono is already installed."
fi

# Wine configuration is already set via environment variables
# No need to run winecfg as it can interfere with 64-bit setup