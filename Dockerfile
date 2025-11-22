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

# ---- Simple entrypoint that runs installer once, then execs CMD ----
RUN printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -e' \
  '' \
  'INSTALL_FLAGS=""' \
  '' \
  '# Build flags from env' \
  'if [ "$DUMP" = "true" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -d"; fi' \
  'if [ -n "$MODE" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -m $MODE"; fi' \
  'if [ -n "$NETWORK" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -n $NETWORK"; fi' \
  'if [ "$TELEMETRY" = "false" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -t"; fi' \
  'if [ "$IGNORE_REQS" = "true" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -i"; fi' \
  'if [ -n "$INSTALL_USER" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -u $INSTALL_USER"; fi' \
  '' \
  'MARKER=/var/ton-work/.mytonctrl-installed' \
  '' \
  '# Ensure ton-work dir exists (host should mount a volume here)' \
  'mkdir -p /var/ton-work' \
  'chown -R '"'"'ton:ton'"'"' /var/ton-work || true' \
  '' \
  'if [ ! -f "$MARKER" ]; then' \
  '  echo "Running MyTonCtrl installer with flags: $INSTALL_FLAGS"' \
  '  cd /home/ton' \
  '  # allow pip to touch system Python if needed (Ubuntu 22.04 is usually fine, but safe)' \
  '  PIP_BREAK_SYSTEM_PACKAGES=1 sudo -E bash ./install.sh $INSTALL_FLAGS' \
  '  sudo touch "$MARKER"' \
  'fi' \
  '' \
  'echo "Starting: $*"' \
  'exec "$@"' \
  > /usr/local/bin/docker-entrypoint.sh && \
  chmod +x /usr/local/bin/docker-entrypoint.sh

# ---- Run as ton by default ----
USER ton
ENV HOME=/home/ton

# Common TON ports (adjust as needed)
# 30303 - P2P, 32768 / 4924 / 4925 - typical liteserver/ADNL ranges
EXPOSE 30303 32768 4924 4925

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
# Default: interactive shell; override CMD to run mytonctrl, etc.
CMD ["bash"]
