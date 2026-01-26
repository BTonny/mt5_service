#!/bin/bash

# Quick MT5 status check script
# Usage: docker exec mt5 /scripts/check-mt5-status.sh

source /scripts/02-common.sh

echo "=== MT5 Installation Status ==="
echo ""

# Check Wine
if [ -d "/config/.wine" ]; then
    echo "✅ Wine prefix exists: /config/.wine"
    if [ -f "/config/.wine/system.reg" ]; then
        ARCH=$(grep -oP '#arch=\K\w+' /config/.wine/system.reg 2>/dev/null | head -1)
        echo "   Architecture: ${ARCH:-unknown}"
    fi
else
    echo "❌ Wine prefix not found"
fi

echo ""

# Check MT5 installation
MT5_PATHS=(
    "/config/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    "/config/.wine/drive_c/Program Files (x86)/MetaTrader 5/terminal64.exe"
)

MT5_FOUND=0
for path in "${MT5_PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo "✅ MT5 installed at: $path"
        MT5_FOUND=1
        # Check file size and date
        SIZE=$(du -h "$path" | cut -f1)
        DATE=$(stat -c %y "$path" 2>/dev/null | cut -d' ' -f1)
        echo "   Size: $SIZE"
        echo "   Installed: $DATE"
        break
    fi
done

if [ $MT5_FOUND -eq 0 ]; then
    echo "❌ MT5 not found in standard locations"
    # Search for it
    ALTERNATIVE=$(find /config/.wine -name "terminal64.exe" 2>/dev/null | head -1)
    if [ -n "$ALTERNATIVE" ]; then
        echo "⚠️  Found alternative location: $ALTERNATIVE"
    else
        echo "⚠️  MT5 installation may still be in progress"
    fi
fi

echo ""

# Check if MT5 process is running
if pgrep -f "terminal64.exe" > /dev/null; then
    echo "✅ MT5 terminal process is running"
    pgrep -f "terminal64.exe" | while read pid; do
        echo "   PID: $pid"
    done
else
    echo "❌ MT5 terminal process is not running"
fi

echo ""

# Check Python/Flask
if pgrep -f "python.*app.py" > /dev/null; then
    echo "✅ Flask is running"
    pgrep -f "python.*app.py" | while read pid; do
        echo "   PID: $pid"
    done
else
    echo "❌ Flask is not running"
fi

echo ""

# Check port
if netstat -tlnp 2>/dev/null | grep -q ":5001" || ss -tlnp 2>/dev/null | grep -q ":5001"; then
    echo "✅ Port 5001 is listening"
else
    echo "❌ Port 5001 is not listening"
fi

echo ""

# Recent setup log
echo "=== Recent Setup Log (last 10 lines) ==="
tail -10 /var/log/mt5_setup.log 2>/dev/null || echo "No setup log found"

echo ""
echo "=== Quick API Test ==="
curl -s http://localhost:5001/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "API not responding"
