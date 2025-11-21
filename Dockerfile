ARG VERSION
FROM ghcr.io/ton-blockchain/ton-docker-ctrl:${VERSION}
LABEL org.opencontainers.image.version=${VERSION}
ENV MODE=liteserver \
    GLOBAL_CONFIG_URL=https://ton.org/global.config.json \
    TELEMETRY=true \
    IGNORE_MINIMAL_REQS=true \
    DUMP=false
WORKDIR /var/ton-work
EXPOSE 30303/udp