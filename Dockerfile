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
RUN wget -O /global.config.json https://ton.org/global.config.json
WORKDIR /var/ton-work/db
VOLUME ["/var/ton-work"]
CMD ["/usr/local/bin/validator-engine", "-C", "/var/ton-work/db/config.json"]