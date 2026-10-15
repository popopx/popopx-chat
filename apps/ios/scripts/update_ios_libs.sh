#!/bin/bash
# Update iOS device and simulator libraries from Nix build
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LIBS_IOS="$PROJECT_ROOT/Libraries/ios"
LIBS_SIM="$PROJECT_ROOT/Libraries/sim"

echo "=== Building iOS libraries with Nix ==="
cd "$PROJECT_ROOT/.."
nix build .#aarch64-darwin-ios:lib:popopx-chat

echo ""
echo "=== Extracting libraries ==="
RESULT_DIR="$(readlink -f result)"
PKG_ZIP="$RESULT_DIR/pkg-ios-aarch64-swift-json.zip"

if [ ! -f "$PKG_ZIP" ]; then
    echo "ERROR: pkg.zip not found at $PKG_ZIP"
    echo "Available files:"
    ls -la "$RESULT_DIR"/pkg*.zip 2>/dev/null || echo "  (no pkg*.zip files found)"
    exit 1
fi

echo "Found: $PKG_ZIP"

# Backup old libraries
if [ -d "$LIBS_IOS" ]; then
    BACKUP_DIR="$LIBS_IOS.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backing up old libraries to: $BACKUP_DIR"
    mv "$LIBS_IOS" "$BACKUP_DIR"
fi

# Extract new libraries
echo "Extracting to: $LIBS_IOS"
mkdir -p "$LIBS_IOS"
unzip -q "$PKG_ZIP" -d "$LIBS_IOS"

echo ""
echo "=== Extracted libraries ==="
ls -lh "$LIBS_IOS"/*.a 2>/dev/null | head -10

echo ""
echo "=== Patching for simulator ==="
mkdir -p "$LIBS_SIM"

# Patch each library for simulator
for lib in "$LIBS_IOS"/*.a; do
    libname="$(basename "$lib")"
    echo "Patching: $libname"
    python3 "$PROJECT_ROOT/Libraries/patch_iossim.py" "$lib" "$LIBS_SIM/$libname"
done

echo ""
echo "=== Simulator libraries ==="
ls -lh "$LIBS_SIM"/*.a 2>/dev/null | head -10

echo ""
echo "=== Verifying libraries ==="
if [ -x "$SCRIPT_DIR/verify_libs.py" ]; then
    python3 "$SCRIPT_DIR/verify_libs.py" --ci
else
    echo "verify_libs.py not found or not executable, skipping verification"
fi

echo ""
echo "=== Library update complete ==="
echo "iOS device libraries: $LIBS_IOS"
echo "Simulator libraries:  $LIBS_SIM"
echo ""
echo "Next steps:"
echo "1. Clean Xcode build: Product > Clean Build Folder (⇧⌘K)"
echo "2. Rebuild and run on real device to verify encrypted URLs"
