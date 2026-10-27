#!/bin/sh

set -e

# iOS device libraries from Nix build
rm -rf ./apps/ios/Libraries/mac ./apps/ios/Libraries/ios
mkdir -p ./apps/ios/Libraries/mac ./apps/ios/Libraries/ios
unzip -o ./result-ios-rebuild/pkg-ios-aarch64-swift-json.zip -d ./apps/ios/Libraries/mac
chmod +w ./apps/ios/Libraries/mac/*
cp ./apps/ios/Libraries/mac/* ./apps/ios/Libraries/ios
MAC2IOS=/nix/store/g40yy1dnxa1z630ih9ip5wj6hrpjx2x7-mac2ios/bin/mac2ios
for f in ./apps/ios/Libraries/ios/*; do $MAC2IOS $f; done | wc -l

# iOS simulator libraries from Nix build (aarch64-darwin-ios-simulator)
rm -rf ./apps/ios/Libraries/sim
mkdir -p ./apps/ios/Libraries/sim
unzip -o ./result-ios-sim/pkg-ios-aarch64-simulator-swift-json.zip -d ./apps/ios/Libraries/sim
chmod +w ./apps/ios/Libraries/sim/*

# Use patch_iossim.py instead of mac2ios -s because mac2ios cannot convert
# LC_VERSION_MIN_IPHONEOS to LC_BUILD_VERSION (required for simulator linking)
PATCH_SCRIPT="$(dirname "$0")/../apps/ios/Libraries/patch_iossim.py"
echo "Patching simulator libraries with patch_iossim.py..."
for f in ./apps/ios/Libraries/sim/*.a; do
    python3 "$PATCH_SCRIPT" "$f" "$f.tmp" && mv "$f.tmp" "$f"
done | grep -c "patched" || echo "Patching complete"
