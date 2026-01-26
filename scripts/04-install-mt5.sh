#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "04-install-mt5.sh"

# Check if MetaTrader 5 is installed
if [ -e "$mt5file" ]; then
    log_message "INFO" "File $mt5file already exists."
else
    log_message "INFO" "File $mt5file is not installed. Installing..."

    # Set Windows 10 mode in Wine and download and install MT5
    WINEARCH=win64 WINEPREFIX=/config/.wine $wine_executable reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f
    log_message "INFO" "Downloading MT5 installer..."
    wget -O /tmp/mt5setup.exe $mt5setup_url > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_message "ERROR" "Failed to download MT5 installer."
        exit 1
    fi
    log_message "INFO" "Installing MetaTrader 5 (this may take 2-3 minutes)..."
    WINEARCH=win64 WINEPREFIX=/config/.wine $wine_executable /tmp/mt5setup.exe /auto > /dev/null 2>&1 &
    INSTALLER_PID=$!
    
    # Wait for installer to complete (max 5 minutes)
    log_message "INFO" "Waiting for MT5 installation to complete..."
    for i in {1..60}; do
        sleep 5
        if [ -e "$mt5file" ]; then
            log_message "INFO" "MT5 installation completed successfully!"
            break
        fi
        if ! ps -p $INSTALLER_PID > /dev/null 2>&1; then
            # Installer process finished, check if file exists
            sleep 5  # Give it a moment to finalize
            if [ -e "$mt5file" ]; then
                log_message "INFO" "MT5 installation completed!"
                break
            else
                log_message "WARN" "MT5 installer finished but file not found. Checking alternative locations..."
                # Check if installed in different location
                ALTERNATIVE=$(find /config/.wine -name "terminal64.exe" 2>/dev/null | head -1)
                if [ -n "$ALTERNATIVE" ]; then
                    log_message "INFO" "Found MT5 at: $ALTERNATIVE"
                    break
                fi
            fi
        fi
        if [ $i -eq 60 ]; then
            log_message "ERROR" "MT5 installation timed out after 5 minutes."
        fi
    done
    rm -f /tmp/mt5setup.exe
fi

# Recheck if MetaTrader 5 is installed
if [ -e "$mt5file" ]; then
    log_message "INFO" "File $mt5file is installed. Running MT5..."
    WINEARCH=win64 WINEPREFIX=/config/.wine $wine_executable "$mt5file" &
else
    log_message "ERROR" "File $mt5file is not installed. MT5 cannot be run."
fi