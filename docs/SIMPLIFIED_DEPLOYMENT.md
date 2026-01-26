# Simplified Deployment (No Traefik)

Complete guide for deploying MT5 service without Traefik - direct port access.

## Why Simplified Version?

- ✅ No port conflicts (doesn't need ports 80/443)
- ✅ Works with existing Nginx/Apache
- ✅ Simpler setup
- ✅ Direct access via IP and ports
- ✅ Perfect for quick deployment

## Prerequisites

- Docker and Docker Compose installed
- Ports 5001 and 3000 available (or change in docker-compose.local.yml)

## Step-by-Step Deployment

### Step 1: Navigate to Project Directory

```bash
cd ~/apps/mt5_service
```

### Step 2: Stop Any Running Containers

```bash
docker compose down
```

### Step 3: Create .env File

```bash
nano .env
```

**Minimum required variables:**

```env
MT5_API_PORT=5001
```

**Note:** `WINEARCH` and `WINEPREFIX` are already set in `docker-compose.local.yml`, so they're optional in `.env` (redundant but harmless if included).

**Optional variables (if needed):**

```env
# Custom user/password for MT5 (if needed)
CUSTOM_USER=admin
PASSWORD=yourpassword
```

### Step 4: Deploy Simplified Version

```bash
docker compose -f docker-compose.local.yml up -d --build
```

This will:
- Build the Docker image
- Install Wine, Mono, MT5, Python libraries
- Start Flask API on port 5001
- Start VNC on port 3000 (optional)

**Build time:** 5-10 minutes (first time)

### Step 5: Monitor Deployment

```bash
# Watch all logs
docker compose -f docker-compose.local.yml logs -f

# Watch MT5 service only
docker compose -f docker-compose.local.yml logs -f mt5

# Check setup log inside container
docker exec mt5 tail -f /var/log/mt5_setup.log
```

### Step 6: Check Container Status

```bash
docker compose -f docker-compose.local.yml ps
```

Expected: `mt5` container should be `Up`

### Step 7: Verify Services

```bash
# Test API health (from VPS)
curl http://localhost:5001/health

# Test from outside VPS
curl http://your-vps-ip:5001/health

# Check if Flask is running
docker exec mt5 ps aux | grep python
```

## Access URLs

After successful deployment:

- **MT5 API:** `http://your-vps-ip:5001`
- **Health Check:** `http://your-vps-ip:5001/health`
- **Swagger Docs:** `http://your-vps-ip:5001/apidocs/`
- **VNC (optional):** `http://your-vps-ip:3000`

## Firewall Configuration

If accessing from outside VPS, open ports:

```bash
sudo ufw allow 5001/tcp  # Flask API
sudo ufw allow 3000/tcp  # VNC (optional)
```

## Common Commands

### View Logs

```bash
# All logs
docker compose -f docker-compose.local.yml logs -f

# MT5 service only
docker compose -f docker-compose.local.yml logs -f mt5

# Last 50 lines
docker compose -f docker-compose.local.yml logs --tail=50 mt5
```

### Restart Service

```bash
# Restart
docker compose -f docker-compose.local.yml restart mt5

# Rebuild and restart
docker compose -f docker-compose.local.yml up -d --build
```

### Stop Service

```bash
docker compose -f docker-compose.local.yml down
```

### Check Container Status

```bash
docker compose -f docker-compose.local.yml ps
docker stats mt5
```

### Access Container Shell

```bash
docker exec -it mt5 bash
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose -f docker-compose.local.yml logs mt5

# Check if port is in use
sudo lsof -i :5001
sudo lsof -i :3000
```

### MT5 Not Initializing

```bash
# Check Wine status
docker exec mt5 wine --version
docker exec mt5 ls -la /config/.wine/

# Check setup log
docker exec mt5 cat /var/log/mt5_setup.log | grep -i error
```

### API Not Accessible

```bash
# Test from VPS
curl http://localhost:5001/health

# Check firewall
sudo ufw status

# Check if service is running
docker exec mt5 ps aux | grep python
```

### Reinstall Everything

```bash
# Stop and remove
docker compose -f docker-compose.local.yml down -v

# Remove config (Wine prefix, MT5 installation)
rm -rf config/

# Rebuild
docker compose -f docker-compose.local.yml up -d --build
```

## Integration with backend_btrade

Update your backend to use:

```env
MT5_API_URL=http://your-vps-ip:5001
```

Or if you set up Nginx reverse proxy:

```env
MT5_API_URL=https://mt5_api.bawembye.com
```

## Adding Nginx Reverse Proxy (Optional)

If you want to use your existing Nginx to proxy to MT5:

**Create Nginx config** (`/etc/nginx/sites-available/mt5`):

```nginx
server {
    listen 80;
    server_name mt5_api.bawembye.com;

    location / {
        proxy_pass http://localhost:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Enable and add SSL:**

```bash
sudo ln -s /etc/nginx/sites-available/mt5 /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
sudo certbot --nginx -d mt5_api.bawembye.com
```

## Quick Reference

```bash
# Start
docker compose -f docker-compose.local.yml up -d

# Stop
docker compose -f docker-compose.local.yml down

# View logs
docker compose -f docker-compose.local.yml logs -f mt5

# Restart
docker compose -f docker-compose.local.yml restart mt5

# Rebuild
docker compose -f docker-compose.local.yml up -d --build

# Check health
curl http://localhost:5001/health
```

## Next Steps

1. ✅ Deploy with simplified version
2. ✅ Test API endpoints
3. ✅ Configure backend_btrade to use `http://your-vps-ip:5001`
4. ✅ (Optional) Set up Nginx reverse proxy for domain access
5. ✅ (Optional) Add SSL with Let's Encrypt via Nginx
