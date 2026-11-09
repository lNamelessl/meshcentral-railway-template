# MeshCentral on Railway - template image.
#
# Pinned to the OFFICIAL meshcentral/meshcentral image, the -mongodb-debian
# variant of release 1.3.1 (2026-10-23): it ships the MongoDB driver and the
# mongodump/mongorestore tools baked in, so the database backend needs no
# runtime npm install. Debian base (glibc) over the Alpine variant for the
# best-tested native-module path. Digest pinned for reproducible builds.
#
# Why a derived image:
#   1. Railway config: TLS is terminated at Railway's edge, so MeshCentral must
#      serve plain HTTP behind it (tlsOffload), trust the edge's forwarded
#      headers (trustedProxy), advertise the external URL (certUrl -> the
#      certificate agents will actually see) and bind the runtime-injected
#      PORT. The upstream image's DYNAMIC_CONFIG env render does most of this,
#      but has no variables for aliasPort/mpsPort/sessionKey/filespath - so
#      this wrapper owns a small idempotent jq render (see railway-entrypoint.sh).
#   2. Zero-credential onboarding: the wrapper seeds the site administrator
#      exactly once via MeshCentral's own `--createaccount`/`--adminaccount`
#      one-shot CLI, guarded by a marker file on the data volume.
#
# The container runs as root (upstream image has no USER directive), which
# matches Railway's root-owned volume mounts - no chown dance needed.
FROM docker.io/meshcentral/meshcentral:1.3.1-mongodb-debian@sha256:8d0464c98882c8b78bac0e6ff7ecbc90913c8a807582d6b81842383807bd8a37

COPY railway-entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh \
    && command -v bash >/dev/null \
    && command -v jq   >/dev/null \
    && command -v curl >/dev/null \
    && command -v node >/dev/null

ENTRYPOINT ["/bin/bash", "/railway-entrypoint.sh"]
