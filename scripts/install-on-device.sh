#!/bin/bash
# Build and install POPOPX on connected iOS device
# Usage: ./scripts/install-on-device.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../apps/ios"

echo "=== Building POPOPX for iOS Device ==="
echo ""

cd "$PROJECT_DIR"

# Check if device is connected
if ! system_profiler SPUSBDataType 2>/dev/null | grep -q "iPhone\|iPad"; then
    echo "❌ No iOS device detected. Please connect a device via USB."
    echo ""
    echo "Available simulators:"
    xcrun simctl list devices | grep -E "iPhone|iPad" | grep "Booted" || echo "  (none booted)"
    exit 1
fi

echo "✅ iOS device detected"
echo ""

# Build for device
echo "Building app..."
xcodebuild \
    -project POPOPX.xcodeproj \
    -scheme "POPOPX (iOS)" \
    -destination 'platform=iOS' \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    clean build 2>&1 | tail -30

BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
    echo ""
    echo "✅ Build succeeded!"
    echo ""
    echo "📱 App should now be installed on your connected device."
    echo ""
    echo "Next steps:"
    echo "1. Open the app on your device"
    echo "2. Complete the onboarding flow"
    echo "3. Kill the app (swipe up from app switcher)"
    echo "4. Relaunch and verify it goes to home page"
    echo ""
    echo "See docs/keychain-persistence-test-plan.md for detailed test scenarios"
else
    echo ""
    echo "❌ Build failed"
    exit 1
fi
