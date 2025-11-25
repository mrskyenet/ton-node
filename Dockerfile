FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ---- Build-time args (for metadata only) ----
ARG VERSION
ARG MODE
ARG NETWORK
ARG TELEMETRY
ARG IGNORE_REQS
ARG DUMP

LABEL org.opencontainers.image.version="${VERSION}"

# ---- Runtime defaults (can be overridden via env / docker-compose) ----
ENV MODE=${MODE:-liteserver} \
    NETWORK=${NETWORK:-mainnet} \
    TELEMETRY=${TELEMETRY:-false} \
    IGNORE_REQS=${IGNORE_REQS:-true} \
    DUMP=${DUMP:-true} \
    INSTALL_USER=ton

# Env vars used by install.sh (from docs)
ENV ARCHIVE_TTL=2592000 \
    STATE_TTL=0 \
    ADD_SHARD="" \
    ARCHIVE_BLOCKS="" \
    COLLATE_SHARD="0:8000000000000000"

# ---- Base packages ----
RUN apt-get update && \
    apt-get install -y \
      curl wget git ca-certificates \
      python3 python3-pip \
      tmux jq sudo \
      build-essential pkg-config libssl-dev \
      && rm -rf /var/lib/apt/lists/*

# ---- Create non-root operator ----
RUN useradd -m -s /bin/bash ton && \
    echo "ton ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /home/ton

# ---- Fetch installer script ----
RUN wget https://raw.githubusercontent.com/ton-blockchain/mytonctrl/master/scripts/install.sh && \
    chmod +x install.sh

# ---- Stub systemctl so install.sh doesn't crash inside container ----
USER root
RUN printf '#!/bin/sh\nexit 0\n' > /usr/bin/systemctl && chmod +x /usr/bin/systemctl

# ---- Start script for TON node (no daemonize: stays in foreground for Docker) ----
RUN cat <<'EOF' >/usr/local/bin/start-ton-node.sh
#!/usr/bin/env bash
set -e

echo "[start-ton-node] launching validator-engine"

exec /usr/bin/ton/validator-engine/validator-engine \
    --threads "$(nproc)" \
    --global-config /usr/bin/ton/global.config.json \
    --db /var/ton-work/db \
    --logname /var/ton-work/log \
    --verbosity 1 \
    --permanent-celldb \
    --state-ttl 1000000000 \
    --archive-ttl 1000000000
EOF
RUN chmod +x /usr/local/bin/start-ton-node.sh

# ---- EntryPoint: run installer ONCE per /var/ton-work, then start node ----
RUN cat <<'EOF' >/usr/local/bin/docker-entrypoint.sh
#!/usr/bin/env bash
set -e

INSTALL_FLAGS=""

# Build flags from env
if [ "$DUMP" = "true" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -d"; fi
if [ -n "$MODE" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -m $MODE"; fi
if [ -n "$NETWORK" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -n $NETWORK"; fi
if [ "$TELEMETRY" = "false" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -t"; fi
if [ "$IGNORE_REQS" = "true" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -i"; fi
if [ -n "$INSTALL_USER" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -u $INSTALL_USER"; fi

MARKER=/var/ton-work/.mytonctrl-installed

# Ensure ton-work dir exists (host should mount a volume here)
mkdir -p /var/ton-work

if [ ! -f "$MARKER" ]; then
  echo "[entrypoint] Running MyTonCtrl installer with flags: $INSTALL_FLAGS"
  cd /home/ton
  PIP_BREAK_SYSTEM_PACKAGES=1 sudo -E bash ./install.sh $INSTALL_FLAGS
  sudo touch "$MARKER"
else
  echo "[entrypoint] MyTonCtrl already installed, skipping installer"
fi

echo "[entrypoint] Starting TON node"
/usr/local/bin/start-ton-node.sh
EOF
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# ---- Run as ton by default ----
USER ton
ENV HOME=/home/ton

# Common TON ports (adjust as needed)
EXPOSE 30303 32768 4924 4925

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD []
