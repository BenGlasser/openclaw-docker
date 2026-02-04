<p align="center">
  <img width="256" height="256" alt="openclaw" src="https://github.com/user-attachments/assets/235dfae8-07e8-43d3-8efd-2bc02345f561" />
</p>

# OpenClaw Docker

Docker container for [OpenClaw](https://github.com/openclaw/openclaw), an AI gateway platform. Built for easy deployment on Unraid and any Docker-compatible system.

## Quick Start

```bash
docker run -d \
  -p 18789:18789 \
  -v openclaw-data:/data/.openclaw \
  -e OPENCLAW_GATEWAY_TOKEN=your-secret-token \
  brglasser/openclaw
```

Then open `http://localhost:18789` to access the OpenClaw Control UI.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_GATEWAY_TOKEN` | *(auto-generated)* | Gateway authentication token. Set this for persistent access across restarts. |

## Volumes

| Path | Description |
|------|-------------|
| `/data/.openclaw` | Persistent data and configuration |

## Ports

| Port | Description |
|------|-------------|
| `18789` | OpenClaw Control UI |

## Unraid

An Unraid template is included for Community Applications. The recommended configuration:

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
- **Health check**: HTTP probe on port 18789 every 30s
