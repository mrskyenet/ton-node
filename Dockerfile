FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ---- Build-time version (for metadata) ----
ARG VERSION
LABEL org.opencontainers.image.version="${VERSION}"
ENV TON_NODE_VERSION=${VERSION}

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
    chmod +x install.sh && \
    sed -i 's/\r$//' install.sh

# ---- Stub systemctl so install.sh / mytoninstaller don't die in Docker ----
USER root
RUN printf '#!/bin/sh\nexit 0\n' > /usr/bin/systemctl && chmod +x /usr/bin/systemctl

# ---- Build TON + MyTonCtrl inside the image (no dump here) ----
USER ton
WORKDIR /home/ton

# NOTE: we do NOT use -d here to avoid baking a DB into the image.
# We just build binaries + tooling; DB will live on the /ton volume at runtime.
RUN PIP_BREAK_SYSTEM_PACKAGES=1 bash ./install.sh \
    -m liteserver \
    -n mainnet \
    -t \
    -i \
    -u ton

# ---- Clean any DB created during build; we want runtime DB on the volume ----
USER root
RUN rm -rf /var/ton-work && mkdir -p /var/ton-work && chown ton:ton /var/ton-work

# ---- Final runtime user ----
USER ton
ENV HOME=/home/ton
WORKDIR /home/ton

# Expose typical liteserver port (we'll map the real one from config.json at runtime)
EXPOSE 30303 50982

# ---- Default: just start validator-engine ----
CMD ["/usr/bin/ton/validator-engine/validator-engine", \
     "--threads","2", \
     "--global-config","/usr/bin/ton/global.config.json", \
     "--db","/var/ton-work/db", \
     "--logname","/var/ton-work/log", \
     "--verbosity","1", \
     "--permanent-celldb", \
     "--state-ttl","1000000000", \
     "--archive-ttl","1000000000"]
