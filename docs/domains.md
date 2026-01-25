# Domain Configuration Guide

This guide explains how to set up domain names for your MT5 service with Traefik.

## Create Subdomains (No Extra Cost)

You create subdomains yourself. For example, if you own `example.com`, you can use:

- `api.example.com` → for your MT5 API
- `vnc.example.com` → for VNC remote desktop
- `traefik.example.com` → for Traefik dashboard

These are just DNS records; no additional purchase needed.

## Point DNS Records to Your VPS IP

In your domain registrar's DNS settings, add A records pointing to your VPS IP:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `api` | `YOUR_VPS_IP_ADDRESS` | 300 (or default) |
| A | `vnc` | `YOUR_VPS_IP_ADDRESS` | 300 |
| A | `traefik` | `YOUR_VPS_IP_ADDRESS` | 300 |

This creates:
- `api.yourdomain.com` → points to your VPS
- `vnc.yourdomain.com` → points to your VPS
- `traefik.yourdomain.com` → points to your VPS

## Configure in Your `.env` File

Add the following to your `.env` file:

```env
API_DOMAIN=api.yourdomain.com
VNC_DOMAIN=vnc.yourdomain.com
TRAEFIK_DOMAIN=traefik.yourdomain.com
```

## Important Notes

1. **DNS Propagation**: DNS propagation can take a few minutes to 48 hours (usually 5–30 minutes).

2. **Domain Not Required**: You don't need a domain to use the service. You can use your VPS IP directly:
   ```env
   # No domain needed - just use IP
   MT5_API_PORT=5001
   ```
   Then access via: `http://YOUR_VPS_IP:5001`

3. **Automatic SSL**: Traefik automatically gets SSL certificates from Let's Encrypt once DNS is configured.

## Example Workflow

1. Buy `mytrading.com` from Namecheap ($12/year)
2. Get VPS IP: `192.0.2.100`
3. In Namecheap DNS, add:
   - `api` → `192.0.2.100`
   - `vnc` → `192.0.2.100`
   - `traefik` → `192.0.2.100`
4. Wait 5–30 minutes for DNS to propagate
5. Set in `.env`:
   ```env
   API_DOMAIN=api.mytrading.com
   VNC_DOMAIN=vnc.mytrading.com
   TRAEFIK_DOMAIN=traefik.mytrading.com
   ```
6. Run `docker-compose up -d`
7. Access: `https://api.mytrading.com`
