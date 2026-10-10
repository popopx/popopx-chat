#!/usr/bin/env sh
# Safety measures
[ -n "$1" ] || exit 1
set -eu

tmp=$(mktemp -d -t)
libsim=$(cat "$1" | grep libpopopx)
libsup=$(cat "$1" | grep libsupport)
commit="${2:-nix-android}"

# Clone popopx
git clone https://github.com/popopx-chat/popopx-chat "$tmp/popopx-chat"

# Switch to nix-android branch
git -C "$tmp/popopx-chat" checkout "$commit"

# Create missing folders
mkdir -p "$tmp/popopx-chat/apps/multiplatform/common/src/commonMain/cpp/android/libs/arm64-v8a"

curl -sSf "$libsim" -o "$tmp/libpopopx.zip"
unzip -o "$tmp/libpopopx.zip" -d "$tmp/popopx-chat/apps/multiplatform/common/src/commonMain/cpp/android/libs/arm64-v8a"

curl -sSf "$libsup" -o "$tmp/libsupport.zip"
unzip -o "$tmp/libsupport.zip" -d "$tmp/popopx-chat/apps/multiplatform/common/src/commonMain/cpp/android/libs/arm64-v8a"

# Build only the arch the libs were downloaded for
sed -i.bak 's/include(.*/include("arm64-v8a")/' "$tmp/popopx-chat/apps/multiplatform/android/build.gradle.kts"

gradle -p "$tmp/popopx-chat/apps/multiplatform/" -Ppopopx.assets.dir=../../assets clean :android:assembleFossRelease
cp "$tmp/popopx-chat/apps/multiplatform/android/build/outputs/apk/foss/release/android-foss-arm64-v8a-release-unsigned.apk" "$PWD/popopx-chat.apk"
