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

# ---- Fetch installer script as root ----
WORKDIR /home/ton
RUN wget https://raw.githubusercontent.com/ton-blockchain/mytonctrl/master/scripts/install.sh && \
    chmod +x install.sh && \
    sed -i 's/\r$//' install.sh

# ---- Stub systemctl so install.sh / mytoninstaller don't die in Docker ----
USER root
RUN printf '#!/bin/sh\nexit 0\n' > /usr/bin/systemctl && chmod +x /usr/bin/systemctl

# ---- Build TON + MyTonCtrl inside the image (no dump here) ----
# NOTE: run as root (required), but tell installer that runtime user is "ton"
RUN PIP_BREAK_SYSTEM_PACKAGES=1 bash /home/ton/install.sh \
    -m liteserver \
    -n mainnet \
    -t \
    -i \
    -u ton

# ---- Clean any build-time DB; runtime DB lives on /var/ton-work volume ----
RUN rm -rf /var/ton-work && mkdir -p /var/ton-work && chown ton:ton /var/ton-work

# ---- Switch to ton for runtime ----
USER ton
ENV HOME=/home/ton
WORKDIR /home/ton

# Expose liteserver port (you’ll still map from config.json; 50982 is your current one)
EXPOSE 30303 50982

# ---- Default: start validator-engine ----
CMD ["/usr/bin/ton/validator-engine/validator-engine", \
     "--threads","2", \
     "--global-config","/usr/bin/ton/global.config.json", \
     "--db","/var/ton-work/db", \
     "--logname","/var/ton-work/log", \
     "--verbosity","1", \
     "--permanent-celldb", \
     "--state-ttl","1000000000", \
     "--archive-ttl","1000000000"]
