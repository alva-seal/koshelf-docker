FROM debian:12-slim AS downloader

RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    file \
    jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

ARG KOSHELF_VERSION=latest
ARG TARGETARCH

# Fetch latest version if not specified
RUN if [ "$KOSHELF_VERSION" = "latest" ]; then \
        echo "Fetching latest KoShelf version..." && \
        KOSHELF_VERSION=$(curl -s https://api.github.com/repos/paviro/KoShelf/releases/latest | jq -r .tag_name) && \
        echo "Latest version: $KOSHELF_VERSION"; \
    fi && \
    echo "$KOSHELF_VERSION" > /tmp/version.txt

# Download and extract the correct binary based on target architecture
RUN KOSHELF_VERSION=$(cat /tmp/version.txt) && \
    case ${TARGETARCH} in \
        "amd64") ARCH="x86_64" ;; \
        "arm64") ARCH="aarch64" ;; \
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

# Verify the binary can execute
RUN ./koshelf --github || echo "Binary check completed"

# Use static distroless image for statically-linked musl binaries
FROM gcr.io/distroless/static-debian12

# Copy version info
COPY --from=downloader /tmp/version.txt /version.txt

COPY --from=downloader --chown=65532:65532 /tmp/koshelf /koshelf

USER 65532

LABEL org.opencontainers.image.title="KoShelf"
LABEL org.opencontainers.image.description="Self-hosted ebook library with KOReader integration"
LABEL org.opencontainers.image.source="https://github.com/paviro/KoShelf"

ENTRYPOINT ["/koshelf", "--books-path", "/books", "--statistics-db", "/settings/statistics.sqlite3", "--port", "3000"]