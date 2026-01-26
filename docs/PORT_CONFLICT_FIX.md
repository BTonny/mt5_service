# Port 80 Conflict Fix

## Problem
```
Error: failed to bind host port for 0.0.0.0:80: address already in use
```

Port 80 is already in use by another service.

## Solution 1: Use Simplified Version (No Traefik) - RECOMMENDED

**Easiest solution - no port conflicts!**

```bash
# Stop current deployment
docker compose down

# Use simplified version (no Traefik)
docker compose -f docker-compose.local.yml up -d --build
```

**Access:**
- API: `http://your-vps-ip:5001`
- Health: `http://your-vps-ip:5001/health`
- Swagger: `http://your-vps-ip:5001/apidocs/`
- VNC: `http://your-vps-ip:3000`

**Advantages:**
- ✅ No port conflicts
- ✅ Simpler setup
- ✅ Works immediately
- ✅ Can add Traefik later if needed

## Solution 2: Fix Port 80 Conflict (For Traefik)

### Step 1: Find What's Using Port 80

```bash
# Check what's using port 80
sudo lsof -i :80

# OR
sudo netstat -tlnp | grep :80

# OR
sudo ss -tlnp | grep :80
```

### Step 2: Stop the Conflicting Service

**If Apache:**
```bash
sudo systemctl stop apache2
sudo systemctl disable apache2  # Prevent auto-start
```

**If Nginx:**
```bash
sudo systemctl stop nginx
sudo systemctl disable nginx  # Prevent auto-start
```

**If Another Docker Container:**
```bash
# List containers
docker ps -a

# Stop and remove conflicting container
docker stop <container-name>
docker rm <container-name>
```

### Step 3: Verify Port 80 is Free

```bash
sudo lsof -i :80
# Should return nothing
```

### Step 4: Retry Deployment

```bash
docker compose up -d --build
```

## Solution 3: Change Traefik Port (Alternative)

If you can't stop the service on port 80, modify `docker-compose.yml`:

```yaml
services:
  traefik:
    ports:
      - 8080:80   # Change external port to 8080
      - 8443:443  # Change external port to 8443
```

Then access Traefik at `http://your-vps-ip:8080` (not recommended for production).

## Recommendation

**Use Solution 1 (Simplified Version)** if:
- You don't need HTTPS/SSL certificates
- You don't need domain names
- You want quick deployment
- You're okay with IP-based access

**Use Solution 2 (Fix Port 80)** if:
- You want Traefik with SSL
- You have domain names configured
- You want production-ready setup

## Quick Check Commands

```bash
# Check port 80
sudo lsof -i :80

# Check port 443
sudo lsof -i :443

# Check all listening ports
sudo netstat -tlnp

# Check Docker containers
docker ps -a
```
