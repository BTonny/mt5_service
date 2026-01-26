#!/bin/bash

# Source common variables and functions
source /scripts/02-common.sh

log_message "INFO" "=== Starting MT5 Service Setup ==="
log_message "INFO" "This process will take 5-15 minutes. Progress will be logged here."

# Start Xvfb virtual display (required for GUI applications in headless environment)
log_message "INFO" "Starting virtual display (Xvfb)..."
# Kill any existing Xvfb processes
pkill -9 Xvfb 2>/dev/null || true
sleep 1

# Remove stale X server lock files
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
log_message "INFO" "Cleaned up stale X server lock files"

# Start Xvfb with proper options
Xvfb :0 -screen 0 1024x768x24 -ac -nolisten tcp +extension GLX +render -noreset > /var/log/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 3
export DISPLAY=:0

# Verify Xvfb is running and display is accessible
if ps -p $XVFB_PID > /dev/null 2>&1; then
    # Test if display is accessible
    if xdpyinfo -display :0 > /dev/null 2>&1; then
        log_message "INFO" "✅ Virtual display started and accessible (PID: $XVFB_PID)"
    else
        log_message "WARN" "⚠️ Xvfb process running but display not accessible yet"
        sleep 2
        if xdpyinfo -display :0 > /dev/null 2>&1; then
            log_message "INFO" "✅ Display now accessible"
        else
            log_message "ERROR" "❌ Display not accessible. Check /var/log/xvfb.log"
        fi
    fi
else
    log_message "ERROR" "❌ Xvfb failed to start. Check /var/log/xvfb.log"
    cat /var/log/xvfb.log 2>/dev/null || true
fi

# Start a simple window manager for VNC (so it's not just a black screen)
log_message "INFO" "Starting window manager for VNC display..."
# Install fluxbox if not already installed (lightweight window manager)
if ! command -v fluxbox >/dev/null 2>&1; then
    log_message "INFO" "Installing fluxbox window manager..."
    apt-get update -qq && apt-get install -y -qq fluxbox >/dev/null 2>&1 || {
        log_message "WARN" "Could not install fluxbox, VNC may show black screen"
    }
fi

# Start fluxbox in background if available
if command -v fluxbox >/dev/null 2>&1; then
    DISPLAY=:0 fluxbox >/var/log/fluxbox.log 2>&1 &
    sleep 2
    log_message "INFO" "✅ Window manager started"
else
    log_message "WARN" "⚠️ No window manager available - VNC may show black screen"
fi

# Start VNC server AFTER Xvfb is confirmed working
# This allows viewing the installation process
log_message "INFO" "Starting VNC server on port 3000 (accessible externally on port 5900)..."
VNC_PASSWORD="${VNC_PASSWORD:-P@55word}"

# Kill any existing x11vnc processes
pkill -9 x11vnc 2>/dev/null || true
sleep 1

# Create VNC password file
mkdir -p ~/.vnc
if command -v x11vnc >/dev/null 2>&1; then
    echo "$VNC_PASSWORD" | x11vnc -storepasswd - ~/.vnc/passwd 2>/dev/null || {
        log_message "WARN" "x11vnc storepasswd failed, using direct password"
    }
fi
chmod 600 ~/.vnc/passwd 2>/dev/null || true

# Start x11vnc server with minimal options for better compatibility
x11vnc -display :0 \
    -forever \
    -shared \
    -rfbport 3000 \
    -passwd "$VNC_PASSWORD" \
    -noxrecord \
    -noxfixes \
    -noxdamage \
    -wait 10 \
    -defer 10 \
    -bg \
    -o /var/log/x11vnc.log \
    2>&1

sleep 3

if pgrep -f "x11vnc" > /dev/null; then
    log_message "INFO" "✅ VNC server started on port 3000 (internal)"
    log_message "INFO" "📺 Connect via VNC client: vnc://your-vps-ip:5900"
    log_message "INFO" "🔑 VNC Password: $VNC_PASSWORD"
else
    log_message "WARN" "⚠️ VNC server may not have started (check /var/log/x11vnc.log)"
    # Try simpler startup
    x11vnc -display :0 -forever -shared -rfbport 3000 -passwd "$VNC_PASSWORD" -bg -o /var/log/x11vnc.log 2>&1
    sleep 2
    if pgrep -f "x11vnc" > /dev/null; then
        log_message "INFO" "✅ VNC server started (fallback method)"
    else
        log_message "WARN" "⚠️ VNC server failed to start - continuing without VNC"
        log_message "WARN" "You can still monitor progress via logs: docker logs -f mt5"
    fi
fi

# Run installation scripts - MT5 MUST succeed
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_message "INFO" "Step 1/5: Installing Mono..."
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
/scripts/03-install-mono.sh
if [ $? -ne 0 ]; then
    log_message "ERROR" "❌ Mono installation failed. Cannot continue."
    exit 1
fi

log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_message "INFO" "Step 2/5: Installing MT5 (this will take 5-10 minutes)..."
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
/scripts/04-install-mt5.sh
if [ $? -ne 0 ]; then
    log_message "ERROR" "❌ MT5 installation failed. Cannot continue without MT5."
    exit 1
fi

log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_message "INFO" "Step 3/5: Installing Python..."
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
/scripts/05-install-python.sh
if [ $? -ne 0 ]; then
    log_message "ERROR" "❌ Python installation failed. Cannot continue."
    exit 1
fi

log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_message "INFO" "Step 4/5: Installing Python libraries..."
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
/scripts/06-install-libraries.sh
if [ $? -ne 0 ]; then
    log_message "ERROR" "❌ Library installation failed. Cannot continue."
    exit 1
fi

log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_message "INFO" "Step 5/5: Starting Flask API..."
log_message "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
/scripts/07-start-wine-flask.sh
if [ $? -ne 0 ]; then
    log_message "ERROR" "❌ Flask startup failed."
    exit 1
fi

log_message "INFO" "=== Setup Complete ==="
log_message "INFO" "Container will continue running. Check logs for status."

# Keep the script running
tail -f /dev/null