# OpenClaw Docker

Docker container for [OpenClaw](https://github.com/openclaw/openclaw), an AI gateway platform. Built for easy deployment on Unraid and any Docker-compatible system.

## Quick Start

```bash
docker run -d \
  -p 18789:18789 \
  -v openclaw-data:/home/node/.openclaw \
  -e OPENCLAW_GATEWAY_TOKEN=your-secret-token \
  benglasser/openclaw
```

Then open `http://localhost:18789` to access the OpenClaw Control UI.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_GATEWAY_TOKEN` | *(auto-generated)* | Gateway authentication token. Set this for persistent access across restarts. |
| `PUID` | `1000` | User ID for file permissions. Set to `99` for Unraid. |
| `PGID` | `100` | Group ID for file permissions. Matches Unraid's `users` group by default. |

## Volumes

| Path | Description |
|------|-------------|
| `/home/node/.openclaw` | Persistent data and configuration |

## Ports

| Port | Description |
|------|-------------|
| `18789` | OpenClaw Control UI |

## Unraid

An Unraid template is included for Community Applications. The recommended configuration:

- **PUID/PGID**: `99`/`100` (Unraid defaults)
- **Data path**: `/mnt/user/appdata/openclaw`

## Building Locally

```bash
docker build -t openclaw .
docker run -d -p 18789:18789 openclaw
```

## Architecture

- **Base image**: `node:22-bookworm`
- **Platforms**: `linux/amd64`, `linux/arm64`
- **Process manager**: `dumb-init` (PID 1 signal handling)
- **Privilege drop**: `gosu` (runs as non-root `node` user)
- **Health check**: HTTP probe on port 18789 every 30s
