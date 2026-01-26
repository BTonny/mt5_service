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

# Kill any stuck wineserver processes from previous attempts
log_message "INFO" "Cleaning up any stuck Wine processes..."
pkill -9 wineserver 2>/dev/null || true
pkill -9 wine 2>/dev/null || true
pkill -9 wine64 2>/dev/null || true
sleep 1

# Try to find wine64 binary first, fallback to wine
WINE_BIN="wine"
if command -v wine64 >/dev/null 2>&1; then
    WINE_BIN="wine64"
    log_message "INFO" "Using wine64 binary for 64-bit initialization..."
else
    log_message "INFO" "Using wine binary with WINEARCH=win64..."
fi

# Verify Wine binary works
if ! $WINE_BIN --version > /dev/null 2>&1; then
    log_message "ERROR" "Wine binary ($WINE_BIN) is not working. Checking installation..."
    if ! command -v wine >/dev/null 2>&1 && ! command -v wine64 >/dev/null 2>&1; then
        log_message "ERROR" "No Wine binaries found. Wine installation may be broken."
        exit 1
    fi
fi

# Start wineserver in background to ensure it's available
log_message "INFO" "Starting wineserver..."
WINEARCH=win64 WINEPREFIX=/config/.wine DISPLAY=:0 wineserver -k 2>/dev/null || true
WINEARCH=win64 WINEPREFIX=/config/.wine DISPLAY=:0 wineserver -p > /dev/null 2>&1 &
WINESERVER_PID=$!
sleep 2

# Verify wineserver is running
if ! kill -0 $WINESERVER_PID 2>/dev/null; then
    log_message "WARN" "wineserver may not have started properly, but continuing..."
else
    log_message "INFO" "wineserver started (PID: $WINESERVER_PID)"
fi

# Function to initialize Wine with aggressive timeout and cleanup
init_wine_with_timeout() {
    local timeout_seconds=60
    local log_file="/tmp/wineboot_init.log"
    
    log_message "INFO" "Running wineboot --init (timeout: ${timeout_seconds}s)..."
    
    # Start wineboot in background with output redirection
    (
        WINEARCH=win64 WINEPREFIX=/config/.wine DISPLAY=:0 $WINE_BIN wineboot --init 2>&1
    ) > "$log_file" 2>&1 &
    local wineboot_pid=$!
    
    # Monitor the process with timeout
    local elapsed=0
    while [ $elapsed -lt $timeout_seconds ]; do
        if ! kill -0 $wineboot_pid 2>/dev/null; then
            # Process finished
            wait $wineboot_pid
            local exit_code=$?
            cat "$log_file" >> /var/log/mt5_setup.log
            rm -f "$log_file"
            return $exit_code
        fi
        
        # Check if system.reg was created (indicates success)
        if [ -f "/config/.wine/system.reg" ]; then
            log_message "INFO" "Wine initialization appears successful (system.reg created)"
            kill $wineboot_pid 2>/dev/null || true
            wait $wineboot_pid 2>/dev/null || true
            cat "$log_file" >> /var/log/mt5_setup.log
            rm -f "$log_file"
            return 0
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    # Timeout reached - kill the process and all Wine processes
    log_message "WARN" "wineboot --init timed out after ${timeout_seconds}s. Killing processes..."
    kill -9 $wineboot_pid 2>/dev/null || true
    # Kill wineserver we started earlier
    if [ -n "$WINESERVER_PID" ] && kill -0 $WINESERVER_PID 2>/dev/null; then
        kill -9 $WINESERVER_PID 2>/dev/null || true
    fi
    pkill -9 wineserver 2>/dev/null || true
    pkill -9 wine 2>/dev/null || true
    pkill -9 wine64 2>/dev/null || true
    sleep 1
    
    cat "$log_file" >> /var/log/mt5_setup.log
    rm -f "$log_file"
    
    return 124  # Timeout exit code
}

# Initialize Wine with timeout
init_wine_with_timeout
WINE_INIT_EXIT=$?

# Check if Wine initialization succeeded
if [ $WINE_INIT_EXIT -ne 0 ] || [ ! -f "/config/.wine/system.reg" ]; then
    if [ $WINE_INIT_EXIT -eq 124 ]; then
        log_message "WARN" "wineboot --init timed out. Attempting fallback initialization method..."
    else
        log_message "WARN" "Wine initialization failed with exit code $WINE_INIT_EXIT. Attempting fallback..."
    fi
    
    # Clean up any remaining processes
    pkill -9 wineserver 2>/dev/null || true
    pkill -9 wine 2>/dev/null || true
    pkill -9 wine64 2>/dev/null || true
    sleep 2
    
    # Fallback: Manually create Wine prefix structure using reg command
    log_message "INFO" "Trying fallback: Manual Wine prefix initialization..."
    
    # Create basic directory structure
    mkdir -p "/config/.wine/drive_c/windows/system32"
    mkdir -p "/config/.wine/drive_c/windows/syswow64"
    mkdir -p "/config/.wine/drive_c/Program Files"
    mkdir -p "/config/.wine/drive_c/users/$(whoami)"
    
    # Try to initialize using reg command (faster, less likely to hang)
    log_message "INFO" "Initializing Wine registry..."
    WINEARCH=win64 WINEPREFIX=/config/.wine DISPLAY=:0 $WINE_BIN reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f > /dev/null 2>&1 &
    local reg_pid=$!
    
    # Wait for reg command with timeout
    local reg_elapsed=0
    while [ $reg_elapsed -lt 30 ]; do
        if ! kill -0 $reg_pid 2>/dev/null; then
            wait $reg_pid 2>/dev/null || true
            break
        fi
        if [ -f "/config/.wine/system.reg" ]; then
            kill $reg_pid 2>/dev/null || true
            break
        fi
        sleep 1
        reg_elapsed=$((reg_elapsed + 1))
    done
    
    # Kill if still running
    kill -9 $reg_pid 2>/dev/null || true
    pkill -9 wineserver 2>/dev/null || true
    sleep 1
    
    # Check if system.reg was created
    if [ -f "/config/.wine/system.reg" ]; then
        log_message "INFO" "✅ Fallback initialization succeeded (system.reg created)"
        WINE_INIT_EXIT=0
    else
        log_message "ERROR" "❌ Both wineboot and fallback initialization failed."
        log_message "ERROR" "Wine system.reg not created. This indicates a serious Wine installation issue."
        
        # Check if Wine is properly installed
        if ! command -v wine >/dev/null 2>&1 && ! command -v wine64 >/dev/null 2>&1; then
            log_message "ERROR" "Wine binary not found! Wine installation may be broken."
            exit 1
        fi
        
        # Check Wine version
        log_message "INFO" "Wine version: $($WINE_BIN --version 2>&1 || echo 'unknown')"
        
        # Check for specific errors in logs
        if grep -q "kernel32.dll" /var/log/mt5_setup.log 2>/dev/null; then
            log_message "ERROR" "Detected kernel32.dll loading failure - Wine core DLLs may be missing"
            log_message "INFO" "This may require Wine dependency reinstallation, but continuing anyway..."
        fi
        
        log_message "ERROR" "Cannot proceed without Wine initialization. Exiting."
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