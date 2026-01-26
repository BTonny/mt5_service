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

# Ensure DISPLAY is set and Xvfb is running
export DISPLAY=${DISPLAY:-:0}
if ! pgrep -f "Xvfb.*:0" > /dev/null; then
    log_message "INFO" "Starting Xvfb for Wine initialization..."
    Xvfb :0 -screen 0 1024x768x24 > /dev/null 2>&1 &
    sleep 2
fi

# Try to find wine64 binary first, fallback to wine
WINE_BIN="wine"
if command -v wine64 >/dev/null 2>&1; then
    WINE_BIN="wine64"
    log_message "INFO" "Using wine64 binary for 64-bit initialization..."
else
    log_message "INFO" "Using wine binary with WINEARCH=win64..."
fi

# Initialize Wine with timeout to prevent hanging
log_message "INFO" "Running wineboot --init (this may take 30-60 seconds)..."
timeout 120 bash -c "WINEARCH=win64 WINEPREFIX=/config/.wine DISPLAY=:0 $WINE_BIN wineboot --init" 2>&1 | tee -a /var/log/mt5_setup.log
WINE_INIT_EXIT=${PIPESTATUS[0]}

# Check if Wine initialization succeeded
if [ $WINE_INIT_EXIT -ne 0 ]; then
    log_message "ERROR" "Wine initialization failed with exit code $WINE_INIT_EXIT"
    log_message "ERROR" "Checking for Wine installation issues..."
    
    # Check if Wine is properly installed
    if ! command -v wine >/dev/null 2>&1 && ! command -v wine64 >/dev/null 2>&1; then
        log_message "ERROR" "Wine binary not found! Wine installation may be broken."
        exit 1
    fi
    
    # Check Wine version
    log_message "INFO" "Wine version: $($WINE_BIN --version 2>&1 || echo 'unknown')"
    
    # Try a simpler initialization without wineboot
    log_message "INFO" "Trying alternative Wine initialization method..."
    WINEARCH=win64 WINEPREFIX=/config/.wine DISPLAY=:0 $WINE_BIN reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f > /dev/null 2>&1
    
    # Check if system.reg was created (indicates successful init)
    if [ ! -f "/config/.wine/system.reg" ]; then
        log_message "ERROR" "Wine system.reg not created. Wine initialization failed."
        log_message "ERROR" "This may indicate missing Wine dependencies or Wine installation issues."
        exit 1
    fi
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