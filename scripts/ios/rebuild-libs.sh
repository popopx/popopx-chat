#!/bin/bash
set -e

echo "=== Rebuilding iOS libraries ==="

# Clean old libraries
rm -rf ./apps/ios/Libraries/mac ./apps/ios/Libraries/ios ./apps/ios/Libraries/sim
mkdir -p ./apps/ios/Libraries/mac ./apps/ios/Libraries/ios ./apps/ios/Libraries/sim

# Extract device libraries
echo "Extracting device libraries..."
unzip -o result/pkg-ios-aarch64-swift-json.zip -d ./apps/ios/Libraries/mac
chmod +w ./apps/ios/Libraries/mac/*
cp ./apps/ios/Libraries/mac/* ./apps/ios/Libraries/ios

# Patch device libs with mac2ios
MAC2IOS=/nix/store/g40yy1dnxa1z630ih9ip5wj6hrpjx2x7-mac2ios/bin/mac2ios
echo "Patching device libraries..."
for f in ./apps/ios/Libraries/ios/*.a; do $MAC2IOS $f; done | wc -l

# Extract simulator libraries
echo "Extracting simulator libraries..."
unzip -o result/pkg-ios-aarch64-simulator-swift-json.zip -d ./apps/ios/Libraries/sim
chmod +w ./apps/ios/Libraries/sim/*

# Patch simulator libs with patch_iossim.py (mac2ios -s doesn't work for LC_VERSION_MIN_IPHONEOS)
echo "Patching simulator libraries..."
PATCH_SCRIPT="$(dirname "$0")/../apps/ios/Libraries/patch_iossim.py"
for f in ./apps/ios/Libraries/sim/*.a; do
    python3 "$PATCH_SCRIPT" "$f" "$f.tmp" && mv "$f.tmp" "$f"
done | grep -c "patched" || echo "Patching complete"

# Add inplace library name for Xcode
echo "Creating inplace library copies..."
cp ./apps/ios/Libraries/sim/libHSpopopx-chat-7.1.0.14-*-ghc9.6.3.a ./apps/ios/Libraries/sim/libHSpopopx-chat-7.1.0.14-inplace-ghc9.6.3.a
cp ./apps/ios/Libraries/mac/libHSpopopx-chat-7.1.0.14-*-ghc9.6.3.a ./apps/ios/Libraries/mac/libHSpopopx-chat-7.1.0.14-inplace-ghc9.6.3.a

# Copy vendor libraries
echo "Copying vendor libraries..."
cp ./apps/ios/Vendor/cactus/apple/libcactus_engine-simulator.a ./apps/ios/Libraries/sim/libcactus_engine.a
cp ./apps/ios/Vendor/cactus/apple/libcactus_engine-device.a ./apps/ios/Libraries/mac/libcactus_engine.a
chmod +w ./apps/ios/Libraries/sim/libcactus_engine.a ./apps/ios/Libraries/mac/libcactus_engine.a

# Patch cactus_engine
echo "Patching cactus_engine..."
$MAC2IOS -s ./apps/ios/Libraries/sim/libcactus_engine.a | wc -l
$MAC2IOS ./apps/ios/Libraries/mac/libcactus_engine.a | wc -l

echo "=== Library rebuild complete ==="
ls -lh ./apps/ios/Libraries/sim/*.a | tail -5
ls -lh ./apps/ios/Libraries/mac/*.a | tail -5
