# VPS Deployment Guide

Complete guide for deploying `mt5_service` to a Linux VPS (Virtual Private Server).

## Table of Contents

- [VPS Requirements](#vps-requirements)
- [VPS Provider Recommendations](#vps-provider-recommendations)
- [Prerequisites](#prerequisites)
- [Deployment Steps](#deployment-steps)
- [Configuration Options](#configuration-options)
- [Security Setup](#security-setup)
- [Integration with backend_btrade](#integration-with-backend_btrade)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Troubleshooting](#troubleshooting)

## VPS Requirements

### Minimum Specifications

- **OS**: Ubuntu 20.04 LTS or newer (22.04 LTS recommended)
- **RAM**: 2GB minimum (4GB+ recommended for stable trading)
- **CPU**: 2 cores minimum
- **Storage**: 20GB minimum (50GB+ recommended)
- **Network**: Stable internet connection (low latency for trading)
- **GUI**: Not required - headless Linux works perfectly

### Why Headless Linux Works

The MT5 application runs entirely inside Docker containers:
- Wine runs MT5 headless inside the container
- Flask API runs on port 5001 (no GUI needed)
- VNC (port 3000) is optional - only for remote desktop access/debugging
- The VPS itself doesn't need a desktop environment

## VPS Provider Recommendations

### Free Options

**Oracle Cloud Always Free** (Best free option)
- 2 AMD VMs (1/8 OCPU, 1GB RAM each) OR 4 ARM VMs (up to 24GB RAM total)
- 200GB storage
- Free forever (no credit card required in some regions)
- Supports Docker and Wine
- Note: ARM instances may need Wine compatibility verification

### Budget Paid Options

- **Vultr**: $2.50/month (minimal specs)
- **DigitalOcean**: $4-6/month (1GB RAM, good for testing)
- **Linode**: $5/month
- **Hetzner**: €4.15/month (~$4.50)
- **AWS EC2**: Pay-as-you-go (t2.small recommended: ~$15/month)

### Recommended for Production

- **DigitalOcean Droplet**: $12/month (2GB RAM, 1 vCPU, 50GB SSD)
- **Linode**: $12/month (2GB RAM, 1 vCPU, 50GB SSD)
- **Vultr**: $12/month (2GB RAM, 1 vCPU, 55GB SSD)

## Prerequisites

### 1. SSH Access to VPS

Ensure you can SSH into your VPS:
```bash
ssh user@your-vps-ip
```

### 2. Docker Installation

Check if Docker is installed:
```bash
docker --version
docker compose version  # Modern Docker (v20.10+) uses 'docker compose' (no hyphen)
# OR
docker compose --version  # Legacy standalone version
```

**Note:** Modern Docker (v20.10+) includes Compose as a plugin. Use `docker compose` (no hyphen) instead of `docker compose`.

If Docker is not installed (Ubuntu/Debian):
```bash
# Update package index
sudo apt update

# Install Docker
sudo apt install -y docker.io

# For Docker Compose (if not included):
# Option 1: Use built-in plugin (Docker 20.10+)
docker compose version  # Should work if Docker is recent

# Option 2: Install standalone docker-compose (if needed)
sudo apt install -y docker-compose

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group (optional, to run without sudo)
sudo usermod -aG docker $USER
# Log out and back in for this to take effect
```

Verify installation:
```bash
docker run hello-world
docker compose version  # Verify Compose plugin
```

### 3. Firewall Configuration

Open required ports:
```bash
# Install UFW if not present
sudo apt install -y ufw

# Allow SSH (important - do this first!)
sudo ufw allow 22/tcp

# Allow Flask API port
sudo ufw allow 5001/tcp

# Allow VNC port (optional, for remote desktop access)
sudo ufw allow 3000/tcp

# Allow HTTP/HTTPS if using Traefik
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

## Deployment Steps

### Step 1: Transfer Files to VPS

**Option A: Using SCP (from your local machine)**
```bash
# From your local machine
scp -r mt5_service/ user@your-vps-ip:/home/user/
```

**Option B: Using Git**
```bash
# On VPS
cd ~
git clone your-repo-url
cd mt5_service
```

**Option C: Using rsync**
```bash
# From your local machine
rsync -avz mt5_service/ user@your-vps-ip:/home/user/mt5_service/
```

### Step 2: Navigate to Project Directory

```bash
ssh user@your-vps-ip
cd ~/mt5_service
```

### Step 3: Create Environment File

Create a `.env` file:
```bash
cp .env.example .env  # If example exists
# OR create new file
nano .env
```

Minimum required variables:
```env
# MT5 API Port (default: 5001)
MT5_API_PORT=5001

# Optional: Traefik Configuration (if using Traefik)
TRAEFIK_DOMAIN=traefik.yourdomain.com
TRAEFIK_USERNAME=admin
TRAEFIK_HASHED_PASSWORD=your_hashed_password
ACME_EMAIL=your-email@example.com

# Optional: VNC Configuration (if using VNC)
VNC_DOMAIN=vnc.yourdomain.com
API_DOMAIN=api.yourdomain.com

# Optional: MT5 Credentials (if needed)
CUSTOM_USER=admin
PASSWORD=yourpassword
```

### Step 4: Create Traefik Network (if using Traefik)

```bash
docker network create traefik-public
```

### Step 5: Build and Start Services

**With Traefik (recommended for production with domain):**
```bash
docker compose up -d --build
# OR if using standalone: docker compose up -d --build
```

**Without Traefik (simpler, direct port access):**
See [Simplified Deployment](#simplified-deployment-without-traefik) section below.

### Step 6: Verify Deployment

Check if containers are running:
```bash
docker ps
```

Check logs:
```bash
# All services
docker compose logs -f

# MT5 service only
docker compose logs -f mt5

# Traefik service only (if using)
docker compose logs -f traefik
```

Test API endpoint:
```bash
curl http://localhost:5001/health
# OR from your local machine
curl http://your-vps-ip:5001/health
```

## Configuration Options

### Option 1: Full Setup with Traefik (Recommended for Production)

**Use when:**
- You have a domain name
- You want HTTPS/SSL certificates
- You want secure access with authentication

**Setup:**
1. Point your domain DNS to VPS IP:
   - `api.yourdomain.com` → VPS IP
   - `vnc.yourdomain.com` → VPS IP (optional)
2. Configure `.env` with domain names
3. Run `docker compose up -d`

**Access:**
- API: `https://api.yourdomain.com`
- VNC: `https://vnc.yourdomain.com` (optional)
- Traefik Dashboard: `https://traefik.yourdomain.com`

### Option 2: Simplified Deployment (Without Traefik)

**Use when:**
- You don't have a domain name
- You want quick testing
- You'll use IP address or set up nginx separately

**Use the included `docker-compose.local.yml` file** (already in the repository):
- No Traefik required
- Direct port access (5001 for API, 3000 for VNC)
- Perfect for quick deployment and testing

**Deploy:**
```bash
docker compose -f docker-compose.local.yml up -d --build
# OR if using standalone: docker-compose -f docker-compose.local.yml up -d --build
```

**Access:**
- API: `http://your-vps-ip:5001`
- Health: `http://your-vps-ip:5001/health`
- Swagger: `http://your-vps-ip:5001/apidocs/`
- VNC: `http://your-vps-ip:3000` (optional)

### Option 3: Using Nginx as Reverse Proxy

**Use when:**
- You have a domain but don't want Traefik
- You want more control over configuration

**Install Nginx:**
```bash
sudo apt install -y nginx
```

**Create Nginx config** (`/etc/nginx/sites-available/mt5`):
```nginx
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Enable and restart:**
```bash
sudo ln -s /etc/nginx/sites-available/mt5 /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

**Add SSL with Let's Encrypt:**
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.yourdomain.com
```

## Security Setup

### 1. Restrict API Access (Recommended)

**Option A: IP Whitelist (if using nginx)**
```nginx
location / {
    allow YOUR_BACKEND_IP;
    deny all;
    proxy_pass http://localhost:5001;
}
```

**Option B: Firewall Rules**
```bash
# Only allow specific IP (your Fly.io backend IP)
sudo ufw delete allow 5001/tcp
sudo ufw allow from YOUR_BACKEND_IP to any port 5001
```

**Option C: API Key Authentication**
Add authentication middleware to Flask app (modify `app/app.py`).

### 2. Keep System Updated

```bash
# Regular updates
sudo apt update && sudo apt upgrade -y

# Docker updates
sudo apt install --only-upgrade docker.io docker-compose
```

### 3. Monitor Logs

Set up log rotation:
```bash
# Create logrotate config
sudo nano /etc/logrotate.d/mt5-docker

# Add:
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=10M
    missingok
    delaycompress
    copytruncate
}
```

### 4. Backup Configuration

```bash
# Backup MT5 config directory
tar -czf mt5-config-backup-$(date +%Y%m%d).tar.gz config/

# Schedule automatic backups (add to crontab)
crontab -e
# Add: 0 2 * * * cd /home/user/mt5_service && tar -czf ~/backups/mt5-config-$(date +\%Y\%m\%d).tar.gz config/
```

## Integration with backend_btrade

### Update backend_btrade Configuration

In your `backend_btrade`, update the MT5 service URL:

**Environment variable** (`.env` or environment config):
```env
MT5_API_URL=http://your-vps-ip:5001
# OR with domain
MT5_API_URL=https://api.yourdomain.com
```

**Update MT5Broker service** (`backend_btrade/src/services/brokers/mt5.py`):
```python
import requests

class MT5Broker(BrokerInterface):
    def __init__(self, api_url: str = None):
        self.api_url = api_url or os.getenv('MT5_API_URL', 'http://localhost:5001')
    
    def place_order(self, symbol: str, side: str, ...):
        response = requests.post(
            f"{self.api_url}/order",
            json={
                "symbol": symbol,
                "type": "BUY" if side == "buy" else "SELL",
                "volume": quantity,
                # ... other params
            }
        )
        return response.json()
    
    def get_positions(self):
        response = requests.get(f"{self.api_url}/get_positions")
        return response.json()
    
    # ... other methods
```

### Test Connection

From your `backend_btrade` (or local machine):
```bash
# Health check
curl http://your-vps-ip:5001/health

# Get positions
curl http://your-vps-ip:5001/get_positions

# Symbol info
curl http://your-vps-ip:5001/symbol_info/EURUSD
```

## Monitoring & Maintenance

### Check Service Status

```bash
# Container status
docker ps

# Service logs
docker compose logs -f mt5

# Resource usage
docker stats mt5
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart mt5

# Rebuild and restart
docker compose up -d --build
```

### Update Application

```bash
cd ~/mt5_service

# Pull latest changes (if using git)
git pull

# Rebuild and restart
docker compose up -d --build
```

### View MT5 Setup Logs

```bash
# Inside container
docker exec -it mt5 cat /var/log/mt5_setup.log

# Or follow logs
docker compose logs -f mt5 | grep -i error
```

## Troubleshooting

### Issue: Container won't start

**Check logs:**
```bash
docker compose logs mt5
```

**Common causes:**
- Port already in use: `sudo lsof -i :5001`
- Insufficient memory: Check `free -h`
- Docker issues: `sudo systemctl restart docker`

### Issue: MT5 not initializing

**Check MT5 installation:**
```bash
docker exec -it mt5 wine /config/.wine/drive_c/Program\ Files/MetaTrader\ 5/terminal64.exe --version
```

**Check Wine:**
```bash
docker exec -it mt5 wine --version
```

**Reinstall MT5 (if needed):**
```bash
# Remove config and restart
rm -rf config/
docker compose restart mt5
```

### Issue: API not accessible from outside

**Check firewall:**
```bash
sudo ufw status
sudo ufw allow 5001/tcp
```

**Check if service is listening:**
```bash
sudo netstat -tlnp | grep 5001
# OR
sudo ss -tlnp | grep 5001
```

**Test from VPS itself:**
```bash
curl http://localhost:5001/health
```

### Issue: High memory usage

**Check resource usage:**
```bash
docker stats mt5
free -h
```

**Solutions:**
- Increase VPS RAM
- Restart container periodically: `docker compose restart mt5`
- Monitor and optimize MT5 settings

### Issue: Connection timeout from backend_btrade

**Check network connectivity:**
```bash
# From backend_btrade server (or your local machine)
ping your-vps-ip
curl -v http://your-vps-ip:5001/health
```

**Check firewall rules:**
```bash
# On VPS
sudo ufw status
sudo iptables -L -n | grep 5001
```

**Check if service is running:**
```bash
docker ps | grep mt5
```

### Issue: SSL Certificate errors (with Traefik)

**Check Traefik logs:**
```bash
docker compose logs traefik | grep -i certificate
```

**Verify DNS:**
```bash
nslookup api.yourdomain.com
```

**Renew certificate manually:**
```bash
docker exec -it traefik certbot renew
```

## Quick Reference Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# Restart service
docker compose restart mt5

# Rebuild after changes
docker compose up -d --build

# Access container shell
docker exec -it mt5 bash

# Check API health
curl http://localhost:5001/health

# View container resource usage
docker stats mt5

# Backup config
tar -czf backup.tar.gz config/

# Restore config
tar -xzf backup.tar.gz
```

## Next Steps

1. ✅ Deploy to VPS
2. ✅ Test API endpoints
3. ✅ Configure firewall
4. ✅ Update `backend_btrade` to use MT5 API
5. ✅ Set up monitoring/alerting
6. ✅ Configure automatic backups
7. ✅ Test trading operations (with demo account first!)

## Support

For issues specific to:
- **MT5 Docker setup**: Check original repo documentation
- **VPS deployment**: Review this guide's troubleshooting section
- **Integration**: Check `backend_btrade` service documentation

---

**Last Updated**: 2024
**Maintained by**: btrade team
