# Troubleshooting Guide

## Connection Issues

### Issue: Connection Reset / Can't Connect

**Symptoms:**
- `curl: (56) Recv failure: Connection reset by peer`
- `curl: (7) Failed to connect to server`

**Diagnosis Steps:**

```bash
# 1. Check container status
docker compose -f docker-compose.local.yml ps

# 2. Check if Flask is running
docker exec mt5 ps aux | grep python

# 3. Check setup logs (most important!)
docker exec mt5 tail -50 /var/log/mt5_setup.log

# 4. Check if service is listening
sudo netstat -tlnp | grep 5001
# OR
sudo ss -tlnp | grep 5001

# 5. Test from inside container
docker exec mt5 curl http://localhost:5001/health

# 6. Check firewall
sudo ufw status
sudo ufw allow 5001/tcp  # If not already open
```

**Common Causes:**

1. **Service Still Starting** (Most Common)
   - Wine/MT5 setup takes 5-10 minutes
   - Wait and check logs: `docker compose -f docker-compose.local.yml logs -f mt5`

2. **Firewall Blocking Port**
   ```bash
   sudo ufw allow 5001/tcp
   sudo ufw reload
   ```

3. **Service Crashed**
   - Check logs: `docker compose -f docker-compose.local.yml logs mt5`
   - Restart: `docker compose -f docker-compose.local.yml restart mt5`

4. **Wine/MT5 Installation Failed**
   - Check: `docker exec mt5 cat /var/log/mt5_setup.log | grep -i error`
   - Reinstall: Remove `config/` and rebuild

## Variable Warnings

### Issue: "The 'XXXXX' variable is not set"

**Cause:** Malformed entry in `.env` file or docker-compose parsing issue.

**Fix:**

```bash
# Check .env file for issues
cat .env

# Common issues:
# - Unescaped $ characters
# - Missing quotes around values with special characters
# - Trailing spaces

# Clean .env file (minimum):
cat > .env << EOF
MT5_API_PORT=5001
EOF
```

## Service Not Starting

### Check Container Logs

```bash
# All logs
docker compose -f docker-compose.local.yml logs mt5

# Follow logs
docker compose -f docker-compose.local.yml logs -f mt5

# Last 100 lines
docker compose -f docker-compose.local.yml logs --tail=100 mt5
```

### Check Setup Progress

```bash
# View setup log
docker exec mt5 cat /var/log/mt5_setup.log

# Check specific steps
docker exec mt5 cat /var/log/mt5_setup.log | grep -E "Wine|MT5|Flask|ERROR"

# Check if Wine initialized
docker exec mt5 test -f /config/.wine/system.reg && echo "Wine OK" || echo "Wine not initialized"

# Check if MT5 installed
docker exec mt5 test -f "/config/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" && echo "MT5 OK" || echo "MT5 not installed"
```

## Port Already in Use

```bash
# Find what's using port 5001
sudo lsof -i :5001
sudo netstat -tlnp | grep 5001

# Stop conflicting service or change port in docker-compose.local.yml
```

## Complete Reset

If everything is broken:

```bash
# Stop and remove everything
docker compose -f docker-compose.local.yml down -v

# Remove Wine/MT5 config
rm -rf config/

# Rebuild from scratch
docker compose -f docker-compose.local.yml up -d --build

# Monitor
docker compose -f docker-compose.local.yml logs -f mt5
```

## Quick Health Check Script

```bash
#!/bin/bash
echo "=== MT5 Service Health Check ==="
echo ""
echo "Container Status:"
docker compose -f docker-compose.local.yml ps
echo ""
echo "Flask Process:"
docker exec mt5 ps aux | grep python || echo "Flask not running"
echo ""
echo "Port 5001:"
sudo netstat -tlnp | grep 5001 || echo "Port 5001 not listening"
echo ""
echo "Last 10 Setup Log Lines:"
docker exec mt5 tail -10 /var/log/mt5_setup.log
echo ""
echo "Health Check:"
curl -s http://localhost:5001/health || echo "Health check failed"
```
