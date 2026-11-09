# Deploy and Host MeshCentral on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/meshcentral-mongodb)

MeshCentral is an open-source remote device management platform: drive remote desktop sessions, terminals, file transfers, and full device inventory from the browser, over HTTPS, with agents for Windows, Linux, and macOS. This template deploys **MeshCentral 1.3.1** (the official Docker image, digest-pinned) with a dedicated **MongoDB 7 database**, and it deploys **with zero prompts** — every variable carries a per-deployment default, including the generated administrator password, so one click lands a working, seeded, persistent server.

Note: other MeshCentral Railway templates run on the embedded NeDB database, which upstream effectively deprecates; the MeshCentral maintainer recommends MongoDB for production-shaped deployments. That database tier, plus the zero-prompt setup and persistent file-transfer/recordings storage, is what this template adds.

## What you get

- **MeshCentral** — public domain, Railway-managed TLS, healthcheck-gated deploys, persistent volume for certificates, config, user files, and session recordings.
- **MongoDB** — private-network only (no public exposure), persistent volume, root credentials generated per deployment.
- **Seeded administrator** — account `admin` is created on first boot via MeshCentral's own CLI with a per-deploy password from the `ADMIN_PASSWORD` variable; further public registration is disabled.
- **Single-domain agent connectivity** — agents and browsers connect over the same HTTPS/WSS domain; no extra ports or TCP proxies for remote desktop, terminal, or file transfer. Intel AMT/CIRA (MPS 4433) is intentionally disabled.

## Post-deploy steps

1. Open your MeshCentral domain and log in as **`admin`** — the password is the `ADMIN_PASSWORD` variable on the MeshCentral service (Variables tab).
2. Change the password in the UI immediately (the seed runs once; UI changes stick).
3. Click **Devices → Add Agent**, pick your platform, and run the shown one-liner on any machine you want to manage. It appears online in seconds.
4. Optional: attach a custom domain, then restart the MeshCentral service so the certificate/agent settings re-render.

## Variables

All variables ship with defaults — nothing is required at deploy time. `MONGO_URL` is composed from the MongoDB service, `HOSTNAME`/`REVERSE_PROXY` follow your Railway domain, `ADMIN_PASSWORD` and `SESSION_KEY` are per-deployment secrets, and `USE_MONGODB`/`TLS_OFFLOAD`/`TRUSTED_PROXY`/`REVERSE_PROXY_TLS_PORT` pin the edge-terminated-TLS behavior.

# Deploy and Host

One click provisions both services with their volumes, private networking, and the public domain. The MeshCentral container waits for MongoDB to accept connections before starting, seeds the administrator once, and serves the web UI on the Railway-injected port behind Railway's TLS edge — healthy from the first boot, no manual configuration required.

## About Hosting

MeshCentral is self-hosted by design: your device management data — inventory, users, session recordings — stays in your own deployment (here, a MongoDB database and a persistent Railway volume you control). Hosting it on Railway gives you a managed always-on server with automatic TLS, private networking between the app and its database, and per-deployment secrets, without exposing the database itself to the internet. The template uses the official upstream Docker image pinned to release 1.3.1 by digest, so upgrades are a conscious choice, not a surprise.

## Why Deploy

- **Proper database tier**: MongoDB 7 instead of the deprecated embedded NeDB default — the backend the MeshCentral maintainer recommends for anything beyond a hobby install.
- **Zero-prompt deploy**: no required variables to research or type; administrator password, session key, and database credentials are generated per deployment and visible in the Variables tab.
- **Seeded and safe**: the admin account exists on first boot, and public account registration is disabled — no race where a stranger claims your fresh server.
- **Single-domain agents**: one HTTPS endpoint serves the web UI and the agent relay, with agent certificate pinning wired to the real edge certificate.
- **Persistent state**: certificates, config, user files, and session recordings live on volumes and survive restarts and redeploys.

## Common Use Cases

- IT support and managed-service providers remotely administering fleets of Windows, Linux, and macOS machines from a browser.
- Homelab and self-hosting enthusiasts managing their machines with full file transfer and terminal access, from anywhere.
- Teams needing auditable remote access: session recordings, event logs, and per-user device groups, stored in your own database.
- Software teams shipping devices or kiosks that phone home to a management server under your control.

## Dependencies for

### Deployment Dependencies

- **MongoDB 7** (official `mongo:7` image) — provisioned by the template with a persistent volume and root credentials generated per deployment; reachable only over Railway private networking.
- **MeshCentral 1.3.1** — official `meshcentral/meshcentral:1.3.1-mongodb-debian` image, digest-pinned; the MongoDB driver is baked into the image (no runtime installs).
- Railway private networking between the two services, plus one public domain with Railway-managed TLS on the MeshCentral service.
- No external services, no API keys, no third-party accounts.
