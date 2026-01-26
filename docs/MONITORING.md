# MT5 Service Monitoring Guide

This guide shows you how to monitor MT5 installation progress and check service status.

## Quick Status Check

### 1. Check Overall Status (Recommended)

```bash
# Run the status check script
docker exec mt5 /scripts/check-mt5-status.sh
```

This shows:
- ✅ Wine installation status
- ✅ MT5 installation status and location
- ✅ MT5 process status
- ✅ Flask API status
- ✅ Port listening status
- ✅ Recent setup logs

### 2. Check via API

```bash
# Basic health check
curl http://localhost:5001/health

# Detailed status (includes installation progress)
curl http://localhost:5001/status | python3 -m json.tool
```

The `/status` endpoint returns:
- `mt5_library.available`: Is MetaTrader5 Python library installed?
- `mt5_library.initialized`: Is MT5 connected?
- `mt5_installation.installed`: Is MT5 installed in Wine?
- `mt5_installation.running`: Is MT5 terminal process running?
- `mt5_installation.path`: Where is MT5 installed?
- `wine.available`: Is Wine configured?
- `setup_log_recent`: Last 5 lines of setup log

## Real-Time Monitoring

### Watch Setup Logs

```bash
# Follow setup log in real-time
docker exec mt5 tail -f /var/log/mt5_setup.log
```

### Watch Container Logs

```bash
# Follow all container logs
docker compose -f docker-compose.local.yml logs -f mt5

# Filter for important messages
docker compose -f docker-compose.local.yml logs -f mt5 | grep -E "INFO|ERROR|WARN|✅|❌"
```

### Monitor Installation Progress

```bash
# Watch for MT5 installation progress
docker exec mt5 tail -f /var/log/mt5_setup.log | grep -E "MT5|installation|progress"
```

## Installation Stages

The installation goes through these stages (you can see them in logs):

1. **Wine Initialization** (30-60 seconds)
   - Look for: `Wine initialized successfully as 64-bit!`

2. **Mono Installation** (30-60 seconds)
   - Look for: `Mono installed successfully.`

3. **MT5 Installation** (2-5 minutes) ⏳
   - Look for: `Installing MetaTrader 5...`
   - Progress updates every 30 seconds
   - Final: `✅ MT5 installation completed successfully!`

4. **Python Installation** (30-60 seconds)
   - Look for: `Python installed in Wine.`

5. **Library Installation** (1-2 minutes)
   - Look for: `Python libraries installed successfully`

6. **Flask Startup** (10-20 seconds)
   - Look for: `✅ Flask server started successfully`
   - Look for: `✅ Flask is listening on port 5001`

## Expected Timeline

- **0-2 minutes**: Wine, Mono, Python setup
- **2-7 minutes**: MT5 installation (this is the longest step)
- **7-9 minutes**: Python libraries and Flask startup
- **9+ minutes**: Everything should be running

## Verification Commands

### Check MT5 Installation

```bash
# Check if MT5 file exists
docker exec mt5 test -f "/config/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" && echo "✅ MT5 installed" || echo "❌ MT5 not installed"

# Find MT5 if in alternative location
docker exec mt5 find /config/.wine -name "terminal64.exe" 2>/dev/null
```

### Check MT5 Process

```bash
# Check if MT5 terminal is running
docker exec mt5 pgrep -f "terminal64.exe" && echo "✅ MT5 running" || echo "❌ MT5 not running"

# See MT5 processes
docker exec mt5 ps aux | grep -E "terminal64|wine"
```

### Check Flask API

```bash
# Check Flask process
docker exec mt5 ps aux | grep python

# Check if port is listening
docker exec mt5 netstat -tlnp | grep 5001 || docker exec mt5 ss -tlnp | grep 5001

# Test API
curl http://localhost:5001/health
```

### Check Wine

```bash
# Check Wine prefix
docker exec mt5 test -f /config/.wine/system.reg && echo "✅ Wine OK" || echo "❌ Wine not initialized"

# Check Wine architecture
docker exec mt5 grep "#arch=" /config/.wine/system.reg | head -1
```

## Troubleshooting

### MT5 Installation Taking Too Long

If MT5 installation is stuck:

```bash
# Check if installer is still running
docker exec mt5 ps aux | grep mt5setup

# Check recent logs
docker exec mt5 tail -20 /var/log/mt5_setup.log

# Check disk space
docker exec mt5 df -h /config
```

### Flask Not Starting

```bash
# Check Flask errors
docker exec mt5 cat /tmp/flask_output.log

# Check Python libraries
docker exec mt5 python3 -c "import flask; print('Flask OK')"
docker exec mt5 python3 -c "import MetaTrader5; print('MT5 library OK')" 2>&1

# Try starting Flask manually
docker exec mt5 python3 /app/app.py
```

### MT5 Not Connecting

```bash
# Check if MT5 process is running
docker exec mt5 pgrep -f terminal64

# Check API status
curl http://localhost:5001/status | python3 -m json.tool

# Restart MT5 terminal
docker exec mt5 bash -c 'WINEARCH=win64 WINEPREFIX=/config/.wine wine "/config/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &'
```

## Continuous Monitoring Script

Create a monitoring script on your VPS:

```bash
#!/bin/bash
# monitor-mt5.sh

while true; do
    clear
    echo "=== MT5 Service Status ==="
    echo ""
    docker exec mt5 /scripts/check-mt5-status.sh
    echo ""
    echo "Press Ctrl+C to stop monitoring"
    sleep 10
done
```

Run it with:
```bash
chmod +x monitor-mt5.sh
./monitor-mt5.sh
```

## What to Look For

### ✅ Good Signs:
- `✅ Wine initialized successfully as 64-bit!`
- `✅ MT5 installation completed successfully!`
- `✅ Flask server started successfully`
- `✅ Flask is listening on port 5001`
- `/status` endpoint shows `mt5_installation.installed: true`
- `/status` endpoint shows `mt5_installation.running: true`

### ⚠️ Warning Signs:
- `⚠️ MT5 installation not complete after 3 minutes` (but Flask should still start)
- `MT5 installer finished but file not found` (checking alternative locations)
- Installation taking longer than 7 minutes

### ❌ Problems:
- `❌ Flask server failed to start`
- `❌ MT5 installation timed out` (after 5 minutes)
- Port 5001 not listening after 10 minutes
- No Flask process running

## Next Steps

Once everything is running:
1. Test the API: `curl http://localhost:5001/health`
2. Check Swagger docs: `http://your-vps-ip:5001/apidocs/`
3. Connect your MT5 account (via VNC or API)
4. Start using the trading endpoints
