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
    
    # Wait for installer to complete (max 5 minutes, but log progress)
    log_message "INFO" "Waiting for MT5 installation to complete (max 5 minutes)..."
    log_message "INFO" "⏳ This may take 2-5 minutes. Installation is running in background."
    MT5_INSTALLED=0
    for i in {1..60}; do
        sleep 5
        elapsed=$((i * 5))
        
        # Check if file exists
        if [ -e "$mt5file" ]; then
            log_message "INFO" "✅ MT5 installation completed successfully! (${elapsed}s)"
            MT5_INSTALLED=1
            break
        fi
        
        # Check if installer process is still running
        if ! ps -p $INSTALLER_PID > /dev/null 2>&1; then
            # Installer process finished, check if file exists
            sleep 5  # Give it a moment to finalize
            if [ -e "$mt5file" ]; then
                log_message "INFO" "✅ MT5 installation completed! (${elapsed}s)"
                MT5_INSTALLED=1
                break
            else
                log_message "INFO" "Installer finished, checking for MT5 files..."
                # Check if installed in different location
                ALTERNATIVE=$(find /config/.wine -name "terminal64.exe" 2>/dev/null | head -1)
                if [ -n "$ALTERNATIVE" ]; then
                    log_message "INFO" "✅ Found MT5 at: $ALTERNATIVE (${elapsed}s)"
                    MT5_INSTALLED=1
                    break
                else
                    # Check if installation is still in progress (files being created)
                    if find /config/.wine -name "*.exe" -newer /tmp/mt5setup.exe 2>/dev/null | grep -q .; then
                        log_message "INFO" "⏳ Installation files detected, waiting a bit longer..."
                        sleep 10
                        ALTERNATIVE=$(find /config/.wine -name "terminal64.exe" 2>/dev/null | head -1)
                        if [ -n "$ALTERNATIVE" ]; then
                            log_message "INFO" "✅ Found MT5 at: $ALTERNATIVE (${elapsed}s)"
                            MT5_INSTALLED=1
                            break
                        fi
                    fi
                fi
            fi
        else
            # Installer still running - log progress
            if [ $((i % 6)) -eq 0 ]; then
                log_message "INFO" "⏳ MT5 installation in progress... (${elapsed}s / 300s)"
            fi
        fi
    done
    
    if [ $MT5_INSTALLED -eq 0 ]; then
        log_message "WARN" "⚠️ MT5 installation not complete after 3 minutes. Continuing anyway..."
        log_message "WARN" "MT5 will be available later. Flask API will start without MT5 for now."
        # Don't exit - let Flask start anyway
    fi
    
    rm -f /tmp/mt5setup.exe
fi

# Recheck if MetaTrader 5 is installed
if [ -e "$mt5file" ]; then
    log_message "INFO" "✅ File $mt5file is installed. Starting MT5..."
    WINEARCH=win64 WINEPREFIX=/config/.wine $wine_executable "$mt5file" > /dev/null 2>&1 &
    log_message "INFO" "MT5 terminal started in background"
else
    # Check for alternative location one more time
    ALTERNATIVE=$(find /config/.wine -name "terminal64.exe" 2>/dev/null | head -1)
    if [ -n "$ALTERNATIVE" ]; then
        log_message "INFO" "✅ Found MT5 at: $ALTERNATIVE. Starting..."
        WINEARCH=win64 WINEPREFIX=/config/.wine $wine_executable "$ALTERNATIVE" > /dev/null 2>&1 &
        log_message "INFO" "MT5 terminal started in background"
    else
        log_message "WARN" "⚠️ MT5 is not installed yet. Flask will start without MT5."
        log_message "WARN" "MT5 installation may still be in progress. It will be available later."
        # Don't exit - continue with Flask startup
    fi
fi