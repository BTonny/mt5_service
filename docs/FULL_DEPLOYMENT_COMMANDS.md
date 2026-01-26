# Full Traefik Deployment Commands

Complete command list for deploying MT5 service with Traefik reverse proxy and SSL.

## Prerequisites

- Domain name with DNS access
- Email address for Let's Encrypt SSL certificates
- DNS records pointing to your VPS IP (configured in Namecheap):
  - `mt5_traefik.bawembye.com` → VPS IP
  - `mt5_api.bawembye.com` → VPS IP
  - `mt5_vnc.bawembye.com` → VPS IP (optional)

## Step-by-Step Commands

### 1. Navigate to Project Directory

```bash
cd ~/apps/mt5_service
```

### 2. Create Traefik Network

```bash
docker network create traefik-public
```

### 3. Generate Traefik Password Hash

```bash
# Replace 'yourpassword' with your desired admin password
docker run --rm httpd:2.4-alpine htpasswd -nbB admin yourpassword
```

**Output example:** `admin:$$apr1$$pbbiaXE4$$DnO9tYBm9NnEIO136xt1p1`

Copy the entire output (including `admin:` prefix).

### 4. Create .env File

```bash
nano .env
```

Add these variables (replace placeholders):

```env
MT5_API_PORT=5001
TRAEFIK_DOMAIN=mt5_traefik.bawembye.com
TRAEFIK_USERNAME=admin
TRAEFIK_HASHED_PASSWORD=admin:$$apr1$$pbbiaXE4$$DnO9tYBm9NnEIO136xt1p1
ACME_EMAIL=your-email@example.com
VNC_DOMAIN=mt5_vnc.bawembye.com
API_DOMAIN=mt5_api.bawembye.com
```

**Important:** 
- Replace `your-email@example.com` with your actual email for Let's Encrypt
- Replace `TRAEFIK_HASHED_PASSWORD` with the hash from step 3

### 5. Configure DNS

Before deploying, ensure DNS records are set:

```bash
# Verify DNS (from your local machine or VPS)
nslookup mt5_traefik.bawembye.com
nslookup mt5_api.bawembye.com
nslookup mt5_vnc.bawembye.com
```

All should resolve to your VPS IP address.

### 6. Configure Firewall

```bash
# Allow HTTP/HTTPS (if not already configured)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Verify firewall status
sudo ufw status
```

### 7. Deploy Full Stack

```bash
# Deploy with Traefik (uses docker-compose.yml by default)
docker compose up -d --build
```

### 8. Monitor Deployment

```bash
# Watch all logs
docker compose logs -f

# Watch specific service
docker compose logs -f traefik
docker compose logs -f mt5
```

### 9. Check Container Status

```bash
docker compose ps
```

Expected output: Both `traefik` and `mt5` containers should be `Up`.

### 10. Verify Services (Wait 2-3 minutes for SSL)

```bash
# Check Traefik dashboard
curl -I https://mt5_traefik.bawembye.com

# Check API health
curl https://mt5_api.bawembye.com/health

# Check VNC
curl -I https://mt5_vnc.bawembye.com
```

## Access URLs

After successful deployment:

- **Traefik Dashboard:** `https://mt5_traefik.bawembye.com`
  - Username: `admin` (or your TRAEFIK_USERNAME)
  - Password: The password you used in step 3

- **MT5 API:** 
  - `https://mt5_api.bawembye.com`
  - `https://mt5_api.bawembye.com/health`
  - `https://mt5_api.bawembye.com/apidocs/` (Swagger documentation)

- **VNC Remote Desktop:** `https://mt5_vnc.bawembye.com` (optional)

## Troubleshooting

### Check Traefik Logs

```bash
docker compose logs -f traefik | grep -i error
docker compose logs traefik | grep -i certificate
```

### Check MT5 Service Logs

```bash
docker compose logs -f mt5
docker exec mt5 cat /var/log/mt5_setup.log
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart traefik
docker compose restart mt5
```

### Rebuild After Changes

```bash
docker compose up -d --build
```

### SSL Certificate Issues

```bash
# Check certificate status
docker compose logs traefik | grep -i certificate

# Verify DNS
nslookup mt5_api.bawembye.com

# Check if ports are accessible
sudo netstat -tlnp | grep -E '80|443'
```

### Common Issues

**Issue:** Containers won't start
```bash
# Check logs
docker compose logs

# Check if network exists
docker network ls | grep traefik-public
```

**Issue:** SSL certificate not issued
- Verify DNS records are correct
- Wait 5-10 minutes for Let's Encrypt
- Check Traefik logs for ACME errors
- Ensure ports 80 and 443 are open

**Issue:** API not accessible
```bash
# Test from VPS
curl http://localhost:5001/health

# Check if MT5 container is running
docker compose ps mt5
```

## Quick Reference

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# Restart service
docker compose restart mt5

# Rebuild and restart
docker compose up -d --build

# Access container shell
docker exec -it mt5 bash
```

## Next Steps

1. ✅ Verify all services are running
2. ✅ Test API endpoints
3. ✅ Configure backend_btrade to use `https://mt5_api.bawembye.com`
4. ✅ Set up monitoring/alerting
5. ✅ Configure automatic backups
