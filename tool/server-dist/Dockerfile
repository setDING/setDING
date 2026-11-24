# Docker image of the setDING server (ADR-0063 §2b), built from the server
# bundle by tool/server-dist/build-image.sh (make server-image). The build
# context holds the unpacked bundle of each architecture in setding-<arch>/
# and an empty pb_data/; a multi-platform build picks the bundle by
# TARGETARCH.
#
# Base: distroless "static" (no shell, no package manager), non-root user
# 65532, pinned by digest; tool/check-deps.sh reports a newer digest or a
# newer Debian series.
FROM gcr.io/distroless/static-debian13:nonroot@sha256:8ce6dd87e9823c5b48dcfb2c8604714ccb351ce59607327bcc4957448da279b5

ARG TARGETARCH
ARG VERSION=unknown
LABEL org.opencontainers.image.title="setDING server" \
      org.opencontainers.image.description="PocketBase backend and web client of setDING" \
      org.opencontainers.image.source="https://github.com/tafli/setDING" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${VERSION}"

# The program belongs to root and is read-only for the server; only the data
# volume is writable (created with its owner, so named volumes inherit it).
COPY --chown=0:0 setding-${TARGETARCH}/ /setding/
COPY --chown=65532:65532 pb_data/ /setding/pb_data/

USER 65532:65532
WORKDIR /setding
VOLUME /setding/pb_data
EXPOSE 8090

# The binary checks itself (no curl in distroless); every 2 s while starting.
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --start-interval=2s --retries=3 \
  CMD ["/setding/pocketbase", "healthcheck"]

ENTRYPOINT ["/setding/pocketbase"]
CMD ["serve", "--http=0.0.0.0:8090", "--dir=/setding/pb_data", "--hooksDir=/setding/pb_hooks", "--hooksWatch=false", "--migrationsDir=/setding/pb_migrations", "--publicDir=/setding/pb_public"]
