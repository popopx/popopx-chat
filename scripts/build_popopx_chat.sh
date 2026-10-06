#!/usr/bin/env bash
set -euo pipefail

# POPOPX Chat CLI Build Script
# Builds the popopx-chat binary from Haskell source
# Requires: GHC 9.6.3, cabal-install 3.10+
# Install via: https://www.haskell.org/ghcup/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "=== POPOPX Chat CLI Builder ==="
echo "Project: $PROJECT_DIR"
echo ""

# Check prerequisites
check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: $1 not found. Install via ghcup: https://www.haskell.org/ghcup/"
    exit 1
  fi
}

check_cmd cabal
check_cmd ghc

echo "GHC: $(ghc --version)"
echo "Cabal: $(cabal --version)"
echo ""

# Update package index
echo "[1/4] Updating package index..."
cabal update

# Configure build
echo "[2/4] Configuring..."
cabal configure \
  --disable-profiling \
  --disable-library-profiling \
  -f swift

# Build
echo "[3/4] Building popopx-chat..."
cabal build popopx-chat

# Report output path
BINARY=$(cabal list-bin popopx-chat)
echo ""
echo "[4/4] Build complete!"
echo "Binary: $BINARY"
echo ""

# Optional: copy to /usr/local/bin
if [[ "${1:-}" == "--install" ]]; then
  INSTALL_DIR="/usr/local/bin"
  echo "Installing to $INSTALL_DIR/popopx-chat ..."
  sudo cp "$BINARY" "$INSTALL_DIR/popopx-chat"
  sudo chmod +x "$INSTALL_DIR/popopx-chat"
  echo "Installed: $(ls -lh "$INSTALL_DIR/popopx-chat")"
  echo ""
  echo "Run: popopx-chat --help"
else
  echo "To install system-wide: $0 --install"
  echo "To run directly: $BINARY --help"
fi
