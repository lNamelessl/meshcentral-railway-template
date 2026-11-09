#!/bin/bash
# Railway wrapper for the official MeshCentral Docker image
# (meshcentral/meshcentral:1.3.1-mongodb-debian).
#
# Boot order (every boot):
#   1. First boot only: copy the upstream config.json.template into meshcentral-data.
#   2. Render Railway environment variables into config.json with jq (idempotent,
#      so domain/PORT changes propagate on restart; only the keys below are
#      touched - any other manual config.json edits are preserved).
#   3. Wait for MongoDB to accept TCP connections (MeshCentral itself exits with
#      code 0 on database failure, so the platform's ON_FAILURE restart policy
#      would never fire - the wait turns that into a hard failure here).
#   4. Seed the site-administrator account ONCE (marker file) using MeshCentral's
#      own one-shot CLI (`--createaccount` / `--adminaccount`), then
#   5. exec the OFFICIAL upstream entrypoint (DYNAMIC_CONFIG=false) unchanged.
#
# The container runs as root (the upstream image has no USER directive), so the
# root-owned Railway volume needs no chown step.
set -u

MC_DIR="/opt/meshcentral/meshcentral"
CONFIG_FILE="${CONFIG_FILE:-/opt/meshcentral/meshcentral-data/config.json}"
TEMPLATE_FILE="/opt/meshcentral/config.json.template"
DATA_DIR="$(dirname "$CONFIG_FILE")"
MARKER_FILE="$DATA_DIR/.admin-seeded"

log() { echo "[railway-entrypoint] $*"; }

# --- 1. First boot: seed config.json from the upstream template ---------------
if [ ! -f "$CONFIG_FILE" ]; then
    log "first boot: creating config.json from upstream template"
    mkdir -p "$DATA_DIR"
    cp "$TEMPLATE_FILE" "$CONFIG_FILE"
fi

# --- 2. Render env -> config.json (idempotent) --------------------------------
# PORT is runtime-injected by Railway; guard against a non-numeric value.
PORT_NUM="${PORT:-443}"
case "$PORT_NUM" in ''|*[!0-9]*) PORT_NUM=443 ;; esac

JQ_ARGS=(--argjson port "$PORT_NUM"
         --arg cert "${HOSTNAME:-localhost}"
         --arg filespath "$DATA_DIR/meshcentral-files")
JQ_FILTER='.settings.port = $port
         | .settings.redirPort = 0
         | .settings.aliasPort = 443
         | .settings.mpsPort = 0
         | .settings.cert = $cert
         | .settings.tlsOffload = true
         | .settings.trustedProxy = true
         | .settings.filespath = $filespath
         | .domains."".NewAccounts = false'

if [ -n "${SESSION_KEY:-}" ]; then
    JQ_ARGS+=(--arg sessionKey "$SESSION_KEY")
    JQ_FILTER="$JQ_FILTER | .settings.sessionKey = \$sessionKey"
fi
if [ -n "${REVERSE_PROXY:-}" ] && [ -n "${REVERSE_PROXY_TLS_PORT:-}" ]; then
    JQ_ARGS+=(--arg rp "$REVERSE_PROXY" --arg rptp "$REVERSE_PROXY_TLS_PORT")
    JQ_FILTER="$JQ_FILTER | .domains.\"\".certUrl = (\$rp + \":\" + \$rptp)"
fi
case "${USE_MONGODB:-}" in
    true|True|TRUE|yes|Yes|YES)
        if [ -n "${MONGO_URL:-}" ]; then
            JQ_ARGS+=(--arg mongoUrl "$MONGO_URL")
            JQ_FILTER="$JQ_FILTER | .settings.mongoDb = \$mongoUrl"
        else
            log "WARNING: USE_MONGODB=true but MONGO_URL is empty; leaving mongoDb disabled"
        fi
        ;;
esac

log "rendering config.json (port=$PORT_NUM cert=${HOSTNAME:-localhost})"
jq "${JQ_ARGS[@]}" "$JQ_FILTER" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" \
    && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE" \
    || { log "jq render failed"; exit 1; }

# --- 3. Wait for MongoDB -------------------------------------------------------
case "${USE_MONGODB:-}" in
    true|True|TRUE|yes|Yes|YES)
        if [ -n "${MONGO_URL:-}" ]; then
            log "waiting for MongoDB to accept TCP connections (max 120s)"
            if ! MONGO_URL="$MONGO_URL" node -e '
const url = new URL(process.env.MONGO_URL);
const net = require("net");
const host = url.hostname, port = parseInt(url.port || "27017", 10);
const deadline = Date.now() + 120000;
(function probe() {
    const s = net.connect({ host: host, port: port, timeout: 4000 });
    s.once("connect", () => { console.log("[railway-entrypoint] MongoDB reachable at " + host + ":" + port); s.destroy(); process.exit(0); });
    s.once("timeout", () => s.destroy());
    s.once("error", () => {
        if (Date.now() > deadline) { console.error("[railway-entrypoint] MongoDB UNREACHABLE at " + host + ":" + port + " after 120s"); process.exit(1); }
        setTimeout(probe, 2000);
    });
})();' ; then
                log "MongoDB never became reachable - exiting so the platform restarts us"
                exit 1
            fi
        fi
        ;;
esac

# --- 4. One-time administrator seed via MeshCentral's own CLI ------------------
# Idempotent by construction: the marker lives on the persistent volume and
# --createaccount itself refuses to overwrite an existing account. The
# ADMIN_PASSWORD variable is only consumed on genuinely first boot; later
# password changes belong in the MeshCentral UI (or via `--resetaccount`
# through `railway ssh`).
if [ -n "${ADMIN_PASSWORD:-}" ] && [ ! -f "$MARKER_FILE" ]; then
    log "seeding administrator account 'admin' (first boot only)"
    SEED_OUT="$(node "$MC_DIR/meshcentral" --configfile "$CONFIG_FILE" --createaccount admin --pass "$ADMIN_PASSWORD" 2>&1)"
    echo "$SEED_OUT"
    case "$SEED_OUT" in *"Done."*|*"User already exists."*) ;; *) log "admin creation failed"; exit 1 ;; esac
    ADMIN_OUT="$(node "$MC_DIR/meshcentral" --configfile "$CONFIG_FILE" --adminaccount admin 2>&1)"
    echo "$ADMIN_OUT"
    case "$ADMIN_OUT" in *"Done."*) ;; *) log "admin promotion failed"; exit 1 ;; esac
    touch "$MARKER_FILE"
    log "administrator account seeded"
elif [ -f "$MARKER_FILE" ]; then
    log "admin marker present, skipping seed"
else
    log "WARNING: ADMIN_PASSWORD empty and no marker; skipping seed (no admin will exist)"
fi

# --- 5. Hand off to the official entrypoint (starts MeshCentral) ---------------
exec /opt/meshcentral/entrypoint.sh
