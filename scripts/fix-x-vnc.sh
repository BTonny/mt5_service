#!/bin/bash
# Quick fix script for X server lock and VNC issues
# Run this inside the container: docker exec mt5 /scripts/fix-x-vnc.sh

echo "=== Fixing X Server and VNC Issues ==="

# Remove stale X server lock files
echo "Removing stale X server lock files..."
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
echo "✅ Lock files removed"

# Kill any stuck X processes
echo "Killing stuck X processes..."
pkill -9 Xvfb 2>/dev/null || true
pkill -9 x11vnc 2>/dev/null || true
sleep 1

# Start Xvfb
echo "Starting Xvfb..."
Xvfb :0 -screen 0 1024x768x24 -ac -nolisten tcp +extension GLX +render -noreset > /var/log/xvfb.log 2>&1 &
sleep 3

# Verify Xvfb is running
if pgrep -f "Xvfb.*:0" > /dev/null; then
    echo "✅ Xvfb started successfully"
else
    echo "❌ Xvfb failed to start. Check /var/log/xvfb.log"
    exit 1
fi

# Start window manager if available
if command -v fluxbox >/dev/null 2>&1; then
    echo "Starting fluxbox window manager..."
    DISPLAY=:0 fluxbox >/var/log/fluxbox.log 2>&1 &
    sleep 2
    echo "✅ Window manager started"
else
    echo "⚠️  fluxbox not available - installing..."
    apt-get update -qq && apt-get install -y -qq fluxbox >/dev/null 2>&1
    if command -v fluxbox >/dev/null 2>&1; then
        DISPLAY=:0 fluxbox >/var/log/fluxbox.log 2>&1 &
        sleep 2
        echo "✅ Window manager installed and started"
    else
        echo "⚠️  Could not install fluxbox - VNC may show black screen"
    fi
fi

# Start VNC server
VNC_PASSWORD="${VNC_PASSWORD:-P@55word}"
echo "Starting VNC server..."
x11vnc -display :0 \
    -forever \
    -shared \
    -rfbport 3000 \
    -passwd "$VNC_PASSWORD" \
    -noxrecord \
    -noxfixes \
    -noxdamage \
    -bg \
    -o /var/log/x11vnc.log \
    2>&1

sleep 2

if pgrep -f "x11vnc" > /dev/null; then
    echo "✅ VNC server started on port 3000"
    echo "📺 Connect via VNC client: vnc://your-vps-ip:5900"
    echo "🔑 VNC Password: $VNC_PASSWORD"
else
    echo "❌ VNC server failed to start. Check /var/log/x11vnc.log"
    exit 1
fi

echo "=== Fix Complete ==="
