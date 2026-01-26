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
    log_message "INFO" "Installing MetaTrader 5 (this may take 3-5 minutes)..."
    log_message "INFO" "⏳ Running installer in background. This will take several minutes..."
    
    # Run installer and capture output for debugging
    WINEARCH=win64 WINEPREFIX=/config/.wine $wine_executable /tmp/mt5setup.exe /auto > /tmp/mt5_installer.log 2>&1 &
    INSTALLER_PID=$!
    log_message "INFO" "Installer started (PID: $INSTALLER_PID)"
    
    # Wait for installer to complete (max 10 minutes)
    log_message "INFO" "Waiting for MT5 installation to complete (max 10 minutes)..."
    MT5_INSTALLED=0
    MAX_WAIT=120  # 10 minutes (120 * 5 seconds)
    
    for i in {1..120}; do
        sleep 5
        elapsed=$((i * 5))
        
        # Log progress every 30 seconds
        if [ $((i % 6)) -eq 0 ]; then
            log_message "INFO" "⏳ MT5 installation in progress... (${elapsed}s / 600s)"
        fi
        
        # Check if file exists in primary location
        if [ -e "$mt5file" ]; then
            log_message "INFO" "✅ MT5 installation completed successfully! (${elapsed}s)"
            MT5_INSTALLED=1
            break
        fi
        
        # Check if installer process is still running
        if ! ps -p $INSTALLER_PID > /dev/null 2>&1; then
            # Installer finished, wait a bit for files to finalize
            log_message "INFO" "Installer process finished. Verifying installation..."
            sleep 10
            
            # Check primary location
            if [ -e "$mt5file" ]; then
                log_message "INFO" "✅ MT5 installation completed! (${elapsed}s)"
                MT5_INSTALLED=1
                break
            fi
            
            # Search for terminal64.exe in Wine prefix
            log_message "INFO" "Searching for MT5 installation..."
            ALTERNATIVE=$(find /config/.wine -name "terminal64.exe" 2>/dev/null | head -1)
            if [ -n "$ALTERNATIVE" ]; then
                log_message "INFO" "✅ Found MT5 at: $ALTERNATIVE (${elapsed}s)"
                # Update mt5file variable to use found location
                mt5file="$ALTERNATIVE"
                MT5_INSTALLED=1
                break
            else
                # Check installer log for errors
                if grep -i "error\|fail" /tmp/mt5_installer.log 2>/dev/null | head -5; then
                    log_message "WARN" "Installer log shows errors. Checking..."
                fi
                log_message "INFO" "MT5 file not found yet. Waiting a bit longer..."
                sleep 15
                # Final check
                ALTERNATIVE=$(find /config/.wine -name "terminal64.exe" 2>/dev/null | head -1)
                if [ -n "$ALTERNATIVE" ]; then
                    log_message "INFO" "✅ Found MT5 at: $ALTERNATIVE (${elapsed}s)"
                    mt5file="$ALTERNATIVE"
                    MT5_INSTALLED=1
                    break
                fi
            fi
        fi
    done
    
    # Verify installation
    if [ $MT5_INSTALLED -eq 0 ]; then
        log_message "ERROR" "❌ MT5 installation FAILED after 10 minutes!"
        log_message "ERROR" "Installer log (last 20 lines):"
        tail -20 /tmp/mt5_installer.log >> /var/log/mt5_setup.log 2>&1 || true
        log_message "ERROR" "Searched locations:"
        log_message "ERROR" "  - $mt5file"
        log_message "ERROR" "  - /config/.wine/drive_c/Program Files (x86)/MetaTrader 5/terminal64.exe"
        find /config/.wine -name "*.exe" -type f 2>/dev/null | head -10 >> /var/log/mt5_setup.log || true
        log_message "ERROR" "Cannot continue without MT5. Exiting..."
        exit 1
    fi
    
    rm -f /tmp/mt5setup.exe
fi

# Verify MT5 is installed before proceeding
if [ ! -e "$mt5file" ]; then
    log_message "ERROR" "❌ MT5 installation verification failed: $mt5file not found"
    exit 1
fi

log_message "INFO" "✅ MT5 verified at: $mt5file"
log_message "INFO" "Starting MT5 terminal..."
WINEARCH=win64 WINEPREFIX=/config/.wine $wine_executable "$mt5file" > /tmp/mt5_terminal.log 2>&1 &
MT5_PID=$!
log_message "INFO" "MT5 terminal started (PID: $MT5_PID)"

# Wait for MT5 to initialize (max 2 minutes)
log_message "INFO" "Waiting for MT5 terminal to initialize..."
MT5_READY=0
for i in {1..24}; do
    sleep 5
    elapsed=$((i * 5))
    
    # Check if MT5 process is still running
    if ! ps -p $MT5_PID > /dev/null 2>&1; then
        log_message "WARN" "MT5 process died. Checking logs..."
        tail -20 /tmp/mt5_terminal.log >> /var/log/mt5_setup.log 2>&1 || true
        # Try starting again
        WINEARCH=win64 WINEPREFIX=/config/.wine $wine_executable "$mt5file" > /tmp/mt5_terminal.log 2>&1 &
        MT5_PID=$!
        log_message "INFO" "Restarted MT5 terminal (PID: $MT5_PID)"
    fi
    
    # Check if MT5 data directory exists (indicates initialization)
    if [ -d "/config/.wine/drive_c/Program Files/MetaTrader 5/MQL5" ] || [ -d "/config/.wine/drive_c/Program Files (x86)/MetaTrader 5/MQL5" ]; then
        log_message "INFO" "✅ MT5 terminal initialized successfully! (${elapsed}s)"
        MT5_READY=1
        break
    fi
    
    if [ $((i % 6)) -eq 0 ]; then
        log_message "INFO" "⏳ Waiting for MT5 initialization... (${elapsed}s / 120s)"
    fi
done

if [ $MT5_READY -eq 0 ]; then
    log_message "WARN" "⚠️ MT5 terminal may not be fully initialized, but continuing..."
    log_message "WARN" "MT5 process is running (PID: $MT5_PID)"
fi

log_message "INFO" "✅ MT5 installation and startup complete!"