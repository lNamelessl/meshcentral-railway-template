# MeshCentral on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/meshcentral-mongodb)

Self-hosted **MeshCentral 1.3.1** — browser-based remote desktop, terminal, file transfer, and device inventory — with a **MongoDB backend** and a **zero-prompt one-click deploy**.

MeshCentral's default embedded database (NeDB) is effectively deprecated; the maintainer recommends MongoDB for anything production-shaped. This template ships that proper database tier and asks for nothing at deploy time: every variable carries a per-deployment default, so you press Deploy and get a working, seeded, persistent server.

## What gets deployed

| Service | Source | Notes |
|---|---|---|
| **MeshCentral** | this repo (Dockerfile on `meshcentral/meshcentral:1.3.1-mongodb-debian`, digest-pinned) | public domain + healthcheck; volume `/opt/meshcentral/meshcentral-data` |
| **MongoDB** | `mongo:7` image | private networking only; volume `/data/db` |

## Sign in

1. Open your MeshCentral domain.
2. Log in as **`admin`** with the value of the `ADMIN_PASSWORD` variable (MeshCentral service → Variables tab — generated per deployment).
3. **Change the password in the UI immediately** (it is only consumed on genuinely first boot; the seed never re-fires afterwards, so UI changes stick).

## Connecting agents (single domain, no extra ports)

Agents and browsers use the same public domain over HTTPS/WSS — remote desktop, terminal, and file transfer all ride the main port. In the web UI: **Devices → Add Agent**, pick your platform, and run the shown one-liner on the machine you want to manage. TLS is terminated by Railway's edge; MeshCentral learns the edge certificate through its `certUrl` setting so agents trust the exact certificate they see.

**Intel AMT / CIRA (MPS port 4433) is disabled** in this template. It is optional, needs its own TCP proxy, and is out of scope — enable it manually if you specifically manage Intel AMT machines.

## Variables (all optional — sensible per-deployment defaults)

| Variable | Default | Purpose |
|---|---|---|
| `MONGO_URL` | composed from the MongoDB service | MongoDB connection string |
| `HOSTNAME` / `REVERSE_PROXY` | `${{RAILWAY_PUBLIC_DOMAIN}}` | server name + external URL used for agent certificate pinning |
| `ADMIN_PASSWORD` | per-deploy secret | initial `admin` password (first boot only) |
| `SESSION_KEY` | per-deploy secret | stable web-session encryption key (sessions survive restarts) |
| `USE_MONGODB=true`, `TLS_OFFLOAD=true`, `TRUSTED_PROXY=true`, `REVERSE_PROXY_TLS_PORT=443` | fixed | runtime behavior |

After attaching a **custom domain**, restart the MeshCentral service so `HOSTNAME`/`REVERSE_PROXY` (bound to `RAILWAY_PUBLIC_DOMAIN`) re-render into the config.

## Operational notes (honest disclosures)

- `config.json` lives on the volume; this image **re-renders the Railway-managed keys on every boot** (port, cert name, tlsOffload, trustedProxy, aliasPort, mpsPort, sessionKey, filespath, mongoDb, certUrl, NewAccounts). Hand edits to *other* keys survive.
- Automatic backups (`autoBackup`, baked `mongodump`) write to `/opt/meshcentral/meshcentral-backups` — **inside the container filesystem, not the volume**. They are lost on redeploy; configure your own off-server backups for anything critical.
- User file transfers and session recordings persist (mapped into the data volume via `filespath`).
- Rotating `MONGO_INITDB_ROOT_PASSWORD` on the MongoDB service after first boot will lock MeshCentral out (the volume already holds the old credential). Reset the database or update the user inside Mongo manually.
- If MongoDB is unreachable at boot, the wrapper exits non-zero so Railway restarts the service (MeshCentral alone would exit cleanly and leave a dead deployment).

## Image pin

`docker.io/meshcentral/meshcentral:1.3.1-mongodb-debian@sha256:8d0464c98882c8b78bac0e6ff7ecbc90913c8a807582d6b81842383807bd8a37`

MeshCentral is Apache-2.0 licensed (Ylianst/MeshCentral). This template is a packaging effort and is not affiliated with the MeshCentral project.
