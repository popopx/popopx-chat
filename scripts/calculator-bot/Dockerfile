# syntax=docker/dockerfile:1

# The runtime glibc must be the same or newer.
ARG UBUNTU_LIBS=22.04
ARG GHC=9.6.3
ARG CABAL=3.10.2.0
ARG NODE=24

# --------------------------------------------------------------------------- #
# libpopopx
# --------------------------------------------------------------------------- #
FROM ubuntu:${UBUNTU_LIBS} AS libpopopx

ARG GHC
ARG CABAL
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git libgmp3-dev libnuma-dev \
        libsqlite3-dev libssl-dev llvm patchelf pkg-config zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_GHC_VERSION=${GHC} \
    BOOTSTRAP_HASKELL_CABAL_VERSION=${CABAL} \
    BOOTSTRAP_HASKELL_INSTALL_NO_STACK=true \
    BOOTSTRAP_HASKELL_INSTALL_NO_STACK_HOOK=true
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
ENV PATH="/root/.ghcup/bin:/root/.cabal/bin:$PATH"
ENV CABAL_DIR=/root/.cabal

WORKDIR /src
COPY cabal.project popopx-chat.cabal README.md PRIVACY.md ./
COPY scripts/cabal.project.local.linux ./cabal.project.local
# The build script checks the export lists in these.
COPY libpopopx.dll.def flake.nix ./
COPY scripts/desktop ./scripts/desktop
COPY src ./src

# VLC is only for the desktop app.
RUN sed -i '/prepare-vlc-linux.sh/d' scripts/desktop/build-lib-linux.sh

# Other versions' build trees are removed: the script's popopx-chat-* glob
# fails with "cd: too many arguments" when the cache holds more than one.
RUN --mount=type=cache,target=/root/.cabal \
    --mount=type=cache,target=/src/dist-newstyle \
    set -eu; \
    ver=$(sed -n 's/^version: *//p' popopx-chat.cabal | tr -d '[:space:]'); \
    build_dir=dist-newstyle/build/$(uname -m)-linux/ghc-${GHC}/popopx-chat-$ver/build; \
    find dist-newstyle/build -maxdepth 3 -type d -name 'popopx-chat-*' \
      ! -path "*/popopx-chat-$ver" -exec rm -rf {} + 2>/dev/null || true; \
    cabal update; \
    scripts/desktop/build-lib-linux.sh sqlite; \
    mkdir -p /libs; \
    cp "$build_dir"/libpopopx.so "$build_dir"/deps/* /libs/

# --------------------------------------------------------------------------- #
# build
# --------------------------------------------------------------------------- #
FROM node:${NODE}-bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential python3 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=libpopopx /libs /opt/popopx/libs
# Without it, npm re-running the library's preinstall downloads the released libs.
ENV POPOPX_LIBS_DIR=/opt/popopx/libs

WORKDIR /src
COPY packages/popopx-chat-client/types/typescript packages/popopx-chat-client/types/typescript
RUN cd packages/popopx-chat-client/types/typescript && \
    npm install --no-audit --no-fund && \
    npx tsc

COPY packages/popopx-chat-nodejs packages/popopx-chat-nodejs
RUN cd packages/popopx-chat-nodejs && \
    npm install --no-audit --no-fund && \
    npm install --no-save --no-audit --no-fund ../popopx-chat-client/types/typescript && \
    npx tsc && \
    cp src/popopx.* dist/

WORKDIR /src/apps/popopx-calculator-bot
# No package-lock.json, so no npm ci.
COPY apps/popopx-calculator-bot/package.json ./
RUN npm install --no-audit --no-fund
RUN npm install --no-save --no-audit --no-fund \
      /src/packages/popopx-chat-nodejs \
      /src/packages/popopx-chat-client/types/typescript

# calculatorBot.test.ts needs network and tests/fixtures/tls.
COPY apps/popopx-calculator-bot ./
RUN npm run build && npx vitest run calculator.test.ts

# --------------------------------------------------------------------------- #
# runtime
# --------------------------------------------------------------------------- #
FROM node:${NODE}-bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates dumb-init libffi8 libgmp10 libssl3 zlib1g && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build --chown=node:node /src /src

# A named volume takes this ownership; a bind mount must be owned by uid 1000.
RUN mkdir -p /src/apps/popopx-calculator-bot/data && \
    chown node:node /src/apps/popopx-calculator-bot/data && \
    chmod 0700 /src/apps/popopx-calculator-bot/data

USER node
WORKDIR /src/apps/popopx-calculator-bot

ENV NODE_ENV=production

# node as PID 1 ignores SIGTERM.
ENTRYPOINT ["dumb-init", "--", "node", "dist/index.js"]
