# Nginx Proxy Setup for Traefik

This document explains the nginx configuration added to proxy traffic to Traefik, and how to remove it when no longer needed.

## What Was Done

Since Traefik runs on ports `9080` (HTTP) and `9443` (HTTPS) to avoid conflicts with nginx on ports `80` and `443`, we configured nginx to proxy requests to Traefik.

### Files Created

1. **Nginx config file**: `/etc/nginx/conf.d/mt5-traefik.conf`
   - Proxies HTTP (port 80) → Traefik (port 9080)
   - Proxies HTTPS (port 443) → Traefik (port 9443)

2. **SSL directory and self-signed certificate**: `/etc/nginx/ssl/`
   - Temporary self-signed certificate for initial HTTPS proxy
   - Traefik will obtain real Let's Encrypt certificates once configured

### Configuration Details

The nginx config proxies these domains:
- `api.mt5.bawembye.com`
- `vnc.mt5.bawembye.com`
- `traefik.mt5.bawembye.com`

All traffic to these domains on ports 80/443 is forwarded to Traefik, which handles routing and SSL certificates.

## How to Remove/Reverse

To completely remove the nginx proxy configuration:

```bash
# 1. Remove the nginx config file
sudo rm /etc/nginx/conf.d/mt5-traefik.conf

# 2. Test nginx configuration
sudo nginx -t

# 3. Reload nginx to apply changes
sudo systemctl reload nginx

# 4. (Optional) Remove the SSL directory if not used elsewhere
sudo rm -rf /etc/nginx/ssl/
```

After removal, nginx will return to its original state and will no longer proxy traffic to Traefik.

## Verification

To verify the proxy is working:

```bash
# Check nginx config is valid
sudo nginx -t

# Check nginx is running
sudo systemctl status nginx

# Test from localhost (should proxy to Traefik)
curl -H "Host: api.mt5.bawembye.com" http://localhost/health
```

## Notes

- The self-signed certificate in `/etc/nginx/ssl/` is only used temporarily for the HTTPS proxy
- Traefik will obtain real SSL certificates from Let's Encrypt once the proxy is working
- This configuration only affects the three MT5 domains listed above
- Other nginx configurations remain unchanged
