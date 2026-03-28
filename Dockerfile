FROM debian:12-slim AS downloader

RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    file \
    jq \
    su-exec \
    passwd \
    bash \
    && rm -rf /var/lib/apt/lists/*
ENV PATH="/usr/sbin:${PATH}"

WORKDIR /tmp

ARG KOSHELF_VERSION=latest
ARG TARGETARCH

RUN if [ "$KOSHELF_VERSION" = "latest" ]; then \
        echo "Fetching latest KoShelf version..." && \
        KOSHELF_VERSION=$(curl -s https://api.github.com/repos/paviro/KoShelf/releases/latest | jq -r .tag_name) && \
        echo "Latest version: $KOSHELF_VERSION"; \
    fi && \
    echo "$KOSHELF_VERSION" > /tmp/version.txt

RUN KOSHELF_VERSION=$(cat /tmp/version.txt) && \
    echo "Building for architecture: ${TARGETARCH}" && \
    case ${TARGETARCH} in \
        amd64) ARCH="x86_64" ;; \
        arm64) ARCH="aarch64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    URL="https://github.com/paviro/KoShelf/releases/download/${KOSHELF_VERSION}/linux-musl-${ARCH}.zip" && \
    echo "Downloading from: ${URL}" && \
    curl -fSL "${URL}" -o koshelf.zip && \
    unzip koshelf.zip && \
    chmod +x koshelf && \
    echo "Downloaded binary info:" && \
    file koshelf && \
    ls -lh koshelf

RUN ./koshelf github || echo "Binary check completed"

FROM alpine:3.22

COPY --from=downloader /tmp/version.txt /app/version.txt
COPY --from=downloader /tmp/koshelf /app/koshelf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

RUN adduser -D -u 1000 koshelf && \
    chown koshelf:koshelf /app/koshelf

ENV KOSHELF_LIBRARY_PATH="/books"
ENV KOSHELF_STATISTICS_DB="/settings/statistics.sqlite3"
ENV KOSHELF_DATA_PATH="/data"
ENV KOSHELF_ENABLE_AUTH="false"
ENV KOSHELF_INCLUDE_UNREAD="false"
ENV KOSHELF_IGNORE_STABLE_METADATA="false"
ENV KOSHELF_PORT="3000"
ENV PATH="/app:${PATH}"

USER 1000

LABEL org.opencontainers.image.title="KoShelf"
LABEL org.opencontainers.image.description="A reading companion powered by KOReader metadata — browse your library, highlights, annotations, and reading statistics from a web dashboard."
LABEL org.opencontainers.image.source="https://github.com/paviro/KoShelf"

ENTRYPOINT ["/entrypoint.sh"]
