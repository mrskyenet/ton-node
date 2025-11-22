ARG VERSION
FROM ubuntu:20.04
ARG VERSION
LABEL org.opencontainers.image.version="${VERSION}"
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      wget unzip fuse libfuse2 ca-certificates && \
    rm -rf /var/lib/apt/lists/*
RUN cd /tmp && \
    wget https://github.com/ton-blockchain/ton/releases/download/${VERSION}/ton-linux-x86_64.zip && \
    unzip ./ton-linux-x86_64.zip -d /usr/local/bin && \
    rm -f /tmp/ton-linux-x86_64.zip
RUN chmod a+x /usr/local/bin/validator-engine /usr/local/bin/validator-engine-console
RUN mkdir -p /var/ton-work/db && \
    mkdir -p /var/ton-work/db/static
ADD global-config.json /global-config.json
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
WORKDIR /var/ton-work/db
VOLUME ["/var/ton-work"]
ENTRYPOINT ["/entrypoint.sh"]
