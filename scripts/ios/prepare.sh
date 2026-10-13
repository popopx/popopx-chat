#!/bin/sh

set -e

# iOS device libraries from Nix build
rm -rf ./apps/ios/Libraries/mac ./apps/ios/Libraries/ios
mkdir -p ./apps/ios/Libraries/mac ./apps/ios/Libraries/ios
unzip -o ./result-ios-rebuild/pkg-ios-aarch64-swift-json.zip -d ./apps/ios/Libraries/mac
chmod +w ./apps/ios/Libraries/mac/*
cp ./apps/ios/Libraries/mac/* ./apps/ios/Libraries/ios
MAC2IOS=/nix/store/0h5lyyscvlngxbp24d1sw5f92a2by7sk-mac2ios/bin/mac2ios
for f in ./apps/ios/Libraries/ios/*; do $MAC2IOS $f; done | wc -l

# iOS simulator libraries from Nix build (aarch64-darwin-ios-simulator)
rm -rf ./apps/ios/Libraries/sim
mkdir -p ./apps/ios/Libraries/sim
unzip -o ./result-ios-sim/pkg-ios-aarch64-simulator-swift-json.zip -d ./apps/ios/Libraries/sim
chmod +w ./apps/ios/Libraries/sim/*
MAC2IOS=/nix/store/0h5lyyscvlngxbp24d1sw5f92a2by7sk-mac2ios/bin/mac2ios
for f in ./apps/ios/Libraries/sim/*; do $MAC2IOS -s $f; done | wc -l
