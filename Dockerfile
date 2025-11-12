FROM rust:1.91-slim AS builder

RUN apt-get update && apt-get install -y \
    git \
    nodejs \
    npm \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ARG KOSHELF_VERSION=main
RUN git clone --depth 1 --branch ${KOSHELF_VERSION} https://github.com/paviro/KoShelf.git .

RUN cargo build --release && \
    strip target/release/koshelf

FROM gcr.io/distroless/cc-debian12

COPY --from=builder /build/target/release/koshelf /usr/local/bin/koshelf

COPY --from=builder --chown=65532:65532 /build/target/release/koshelf /koshelf

USER 65532

ENTRYPOINT ["/koshelf", "--books-path", "/books", "--statistics-db", "/settings/statistics.sqlite3", "--port", "3000"]
