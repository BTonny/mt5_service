# Local Development Setup

This guide helps you run the MT5 service locally without Traefik.

## Quick Start

### 1. Create `.env` file

Create a `.env` file in the project root with:

```env
MT5_API_PORT=5001
```

That's it! No Traefik variables needed for local development.

### 2. Build and Start

Use the simplified local compose file:

```bash
docker-compose -f docker-compose.local.yml up -d --build
```

### 3. Check Logs

```bash
docker-compose -f docker-compose.local.yml logs -f mt5
```

Wait for "Flask server started successfully" message.

### 4. Test the API

```bash
# Health check
curl http://localhost:5001/health

# Swagger docs
open http://localhost:5001/apidocs/
```

### 5. Access VNC (Optional)

If you need to log into MT5 manually:
- Open browser: `http://localhost:3000`
- Log into MT5 with your account credentials

## Access Points

- **API**: `http://localhost:5001`
- **Health Check**: `http://localhost:5001/health`
- **Swagger Docs**: `http://localhost:5001/apidocs/`
- **VNC Desktop**: `http://localhost:3000` (optional)

## Commands

```bash
# Start services
docker-compose -f docker-compose.local.yml up -d

# Stop services
docker-compose -f docker-compose.local.yml down

# View logs
docker-compose -f docker-compose.local.yml logs -f mt5

# Restart
docker-compose -f docker-compose.local.yml restart mt5

# Rebuild
docker-compose -f docker-compose.local.yml up -d --build
```

## Differences from Production

The `docker-compose.local.yml` file:
- ✅ No Traefik (simpler, faster)
- ✅ Direct port mapping (5001, 3000)
- ✅ No domain/SSL configuration needed
- ✅ No external network required

For production deployment, use `docker-compose.yml` with proper Traefik configuration.
