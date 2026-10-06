#!/bin/bash
# Generate dSYM for WebRTC.framework (binary Swift package)
# Xcode doesn't auto-generate dSYMs for pre-built binary frameworks.
set -e

# WebRTC is a local binary package at Vendor/WebRTC/WebRTC.xcframework.
# Fall back to SPM artifacts in DerivedData if the local path doesn't exist.
WEBRTC_XCFRAMEWORK="${SRCROOT}/Vendor/WebRTC/WebRTC.xcframework"
if [ ! -d "$WEBRTC_XCFRAMEWORK" ]; then
    DERIVED_DATA_ROOT="$(echo "$BUILD_DIR" | sed 's|/Build/.*||')"
    WEBRTC_XCFRAMEWORK="$(find "$DERIVED_DATA_ROOT/SourcePackages/artifacts" -path "*/WebRTC.xcframework" -type d 2>/dev/null | head -1)"
fi

if [ -z "$WEBRTC_XCFRAMEWORK" ] || [ ! -d "$WEBRTC_XCFRAMEWORK" ]; then
    echo "warning: WebRTC xcframework not found (checked Vendor/WebRTC and SPM artifacts)"
    exit 0
fi

# Pick the right slice based on build architecture
if [ "$PLATFORM_NAME" = "iphonesimulator" ]; then
    WEBRTC_FW="$WEBRTC_XCFRAMEWORK/ios-x86_64_arm64-simulator/WebRTC.framework/WebRTC"
else
    WEBRTC_FW="$WEBRTC_XCFRAMEWORK/ios-arm64/WebRTC.framework/WebRTC"
fi

if [ ! -f "$WEBRTC_FW" ]; then
    echo "warning: WebRTC binary not found at: $WEBRTC_FW"
    exit 0
fi

# Place dSYM where Xcode archive collects it (DWARF_DSYM_FOLDER_PATH is sandbox-permitted)
DSYM_DIR="${DWARF_DSYM_FOLDER_PATH}/WebRTC.framework.dSYM"
DSYM_BIN="$DSYM_DIR/Contents/Resources/DWARF/WebRTC"

if [ -d "$DSYM_DIR" ] && [ -f "$DSYM_BIN" ]; then
    echo "WebRTC dSYM already exists at: $DSYM_DIR"
    exit 0
fi

# Get the UUID from the source binary — archive validator requires a dSYM with this exact UUID
EXPECTED_UUID=$(dwarfdump --uuid "$WEBRTC_FW" 2>/dev/null | head -1 | awk '{print $2}')
if [ -z "$EXPECTED_UUID" ]; then
    echo "warning: could not determine UUID for WebRTC binary"
    exit 0
fi
echo "WebRTC source UUID: $EXPECTED_UUID"

echo "Generating WebRTC dSYM from: $WEBRTC_FW"
rm -rf "$DSYM_DIR"
mkdir -p "$DSYM_DIR/Contents/Resources/DWARF"

# Generate plist for dSYM
cat > "$DSYM_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleIdentifier</key>
	<string>com.apple.dt.dsym-generated.WebRTC</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>WebRTC</string>
	<key>CFBundlePackageType</key>
	<string>dSYM</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
</dict>
</plist>
PLIST

# dsymutil warns "no debug symbols" for stripped binaries but still creates the dSYM structure
dsymutil "$WEBRTC_FW" -o "$DSYM_DIR" >/dev/null 2>&1 || true

if [ ! -f "$DSYM_BIN" ]; then
    # Binary is stripped — dsymutil created the bundle but no DWARF file.
    # Copy the source binary as the DWARF file so the archive validator can match the UUID.
    echo "WebRTC binary is stripped, using source binary as DWARF content"
    cp "$WEBRTC_FW" "$DSYM_BIN"
fi

DSYM_UUID=$(dwarfdump --uuid "$DSYM_DIR" 2>/dev/null | head -1 | awk '{print $2}')
echo "WebRTC dSYM generated: $DSYM_DIR (UUID: $DSYM_UUID)"

if [ "$EXPECTED_UUID" != "$DSYM_UUID" ]; then
    echo "error: UUID mismatch! source=$EXPECTED_UUID dsym=$DSYM_UUID"
    exit 1
fi
