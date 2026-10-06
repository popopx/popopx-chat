#!/bin/bash
# Applies the base64url decodeLenient patch to the cabal-fetched popopxmq source.
# This mirrors what the Nix build does in flake.nix.
# Run after `cabal update` or whenever dist-newstyle is regenerated.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PATCH_FILE="$PROJECT_ROOT/scripts/nix/popopxmq-base64url-decodeLenient.patch"

if [ ! -f "$PATCH_FILE" ]; then
    echo "ERROR: Patch file not found: $PATCH_FILE"
    exit 1
fi

POPOPXMQ_SRC=$(find "$PROJECT_ROOT/dist-newstyle/src" -maxdepth 1 -type d -name 'popopxmq-*' | head -1)

if [ -z "$POPOPXMQ_SRC" ]; then
    echo "ERROR: popopxmq source not found in dist-newstyle/src/"
    echo "Run 'cabal update' first to fetch sources."
    exit 1
fi

TARGET_FILE="$POPOPXMQ_SRC/src/Popopx/Messaging/Encoding/String.hs"

if [ ! -f "$TARGET_FILE" ]; then
    echo "ERROR: String.hs not found at $TARGET_FILE"
    exit 1
fi

if grep -q 'decodeLenient' "$TARGET_FILE"; then
    echo "Patch already applied to $TARGET_FILE"
else
    cd "$POPOPXMQ_SRC"
    patch -p1 < "$PATCH_FILE"
    echo "Patch applied successfully to $TARGET_FILE"
fi
