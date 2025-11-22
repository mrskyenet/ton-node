FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ---- Build-time config (feel free to tweak) ----
ARG MODE=liteserver       # validator|liteserver|collator|...
ARG NETWORK=mainnet       # mainnet|testnet
ARG TELEMETRY=false       # true|false (false => pass -t)
ARG IGNORE_REQS=true      # true|false (true => pass -i)
ARG DUMP=true             # true|false (true => pass -d)

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

# ---- Non-root operator (as MyTonCtrl expects) ----
RUN useradd -m -s /bin/bash ton && \
    echo "ton ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ton
WORKDIR /home/ton

# ---- Fetch installer script ----
RUN wget https://raw.githubusercontent.com/ton-blockchain/mytonctrl/master/scripts/install.sh && \
    chmod +x install.sh

# ---- Run installer non-interactively during build ----
RUN set -eux; \
    INSTALL_FLAGS=""; \
    if [ "$DUMP" = "true" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -d"; fi; \
    if [ -n "$MODE" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -m $MODE"; fi; \
    if [ -n "$NETWORK" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -n $NETWORK"; fi; \
    if [ "$TELEMETRY" = "false" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -t"; fi; \
    if [ "$IGNORE_REQS" = "true" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -i"; fi; \
    sudo bash ./install.sh $INSTALL_FLAGS

# Optionally expose some common ports (tune for your setup)
EXPOSE 30303 32768 4924 4925

# Default: drop you into a shell so you can run `mytonctrl`
CMD ["bash"]
