#!/bin/bash

# Source common variables and functions
source /scripts/02-common.sh

log_message "INFO" "=== Starting MT5 Service Setup ==="
log_message "INFO" "This process will take 5-15 minutes. Progress will be logged here."

# Start Xvfb virtual display (required for GUI applications in headless environment)
log_message "INFO" "Starting virtual display (Xvfb)..."
Xvfb :0 -screen 0 1024x768x24 > /dev/null 2>&1 &
XVFB_PID=$!
sleep 2
export DISPLAY=:0
if ps -p $XVFB_PID > /dev/null 2>&1; then
    log_message "INFO" "✅ Virtual display started (PID: $XVFB_PID)"
else
    log_message "WARN" "⚠️ Virtual display may not have started"
fi

# Start VNC server to allow remote viewing of installation
log_message "INFO" "Starting VNC server on port 3000 (accessible externally on port 5900)..."
VNC_PASSWORD="${VNC_PASSWORD:-P@55word}"

# Create VNC password file using x11vnc's storepasswd
mkdir -p ~/.vnc
echo "$VNC_PASSWORD" | x11vnc -storepasswd - ~/.vnc/passwd 2>/dev/null || {
    # Fallback: create password file manually if storepasswd fails
    log_message "WARN" "Using fallback VNC password method..."
    echo "$VNC_PASSWORD" | vncpasswd -f > ~/.vnc/passwd 2>/dev/null || true
}
chmod 600 ~/.vnc/passwd 2>/dev/null || true

# Start x11vnc server (connects to Xvfb display :0)
x11vnc -display :0 \
    -noxrecord \
    -noxfixes \
    -noxdamage \
    -forever \
    -shared \
    -rfbport 3000 \
    -rfbauth ~/.vnc/passwd \
    -bg \
    -o /var/log/x11vnc.log \
    -passwd "$VNC_PASSWORD" 2>&1

sleep 2

if pgrep -f "x11vnc" > /dev/null; then
    log_message "INFO" "✅ VNC server started on port 3000 (internal)"
    log_message "INFO" "📺 Connect via VNC client: vnc://your-vps-ip:5900"
    log_message "INFO" "🔑 VNC Password: $VNC_PASSWORD"
else
    log_message "WARN" "⚠️ VNC server may not have started (check /var/log/x11vnc.log)"
    # Try starting without password file (using -passwd directly)
    x11vnc -display :0 -forever -shared -rfbport 3000 -passwd "$VNC_PASSWORD" -bg -o /var/log/x11vnc.log 2>&1
    sleep 1
    if pgrep -f "x11vnc" > /dev/null; then
        log_message "INFO" "✅ VNC server started (fallback method)"
        log_message "INFO" "📺 Connect via VNC client: vnc://your-vps-ip:5900"
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