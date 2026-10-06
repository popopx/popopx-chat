#!/bin/bash
# Diagnostic script for Keychain persistence testing
# Run this AFTER testing on a real device to collect diagnostic info

set -e

echo "=== POPOPX Keychain Persistence Diagnostics ==="
echo ""
echo "This script collects diagnostic information from your connected iOS device."
echo "Make sure your device is connected via USB and unlocked."
echo ""

# Check for connected device (optional for code diagnostics)
if system_profiler SPUSBDataType 2>/dev/null | grep -q "iPhone\|iPad"; then
    echo "✅ Device detected"
else
    echo "⚠️  No iOS device detected (connect device for full testing)"
fi
echo ""

# Check git commits
echo "=== Recent Commits ==="
cd /Users/elliot/simple-chat/POPOPX
git log --oneline -3 | grep -E "Keychain|persistence|restart" || echo "⚠️  Keychain fix commits not found"
echo ""

# Check entitlements in built app
echo "=== App Entitlements ==="
APP_PATH="/Users/elliot/Library/Developer/Xcode/DerivedData/POPOPX-*/Build/Products/Debug-iphoneos/POPOPX.app"
if [ -d "$APP_PATH" ]; then
    codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | grep -A5 "keychain-access-groups" || echo "⚠️  Could not read entitlements"
else
    echo "⚠️  Built app not found. Please build the app first."
fi
echo ""

# Check if app is installed (requires ideviceinstaller, optional)
if command -v ideviceinstaller &> /dev/null; then
    echo "=== Installed Apps ==="
    ideviceinstaller -l | grep popopx || echo "⚠️  POPOPX not installed on device"
    echo ""
else
    echo "ℹ️  ideviceinstaller not installed (optional for diagnostics)"
    echo "   Install with: brew install ideviceinstaller"
    echo ""
fi

# Show KeyChain.swift current state
echo "=== KeyChain.swift Access Policy ==="
grep -A2 "ACCESS_POLICY" /Users/elliot/simple-chat/POPOPX/apps/ios/POPOPXSwitch/KeyChain.swift | head -3
echo ""

echo "=== KeyChain.swift baseItemQuery ==="
grep -A5 "private func baseItemQuery" /Users/elliot/simple-chat/POPOPX/apps/ios/POPOPXSwitch/KeyChain.swift
echo ""

# Show PXChatState init
echo "=== PXChatState init() ==="
grep -A8 "init()" /Users/elliot/simple-chat/POPOPX/apps/ios/Shared/Model/PXChatState.swift | head -10
echo ""

# Show POPOPXApp.onAppear logic
echo "=== POPOPXApp onAppear Logic ==="
grep -B2 -A10 "DEFAULT_ONBOARDING_STAGE" /Users/elliot/simple-chat/POPOPX/apps/ios/Shared/POPOPXApp.swift | head -15
echo ""

echo "=== Next Steps ==="
echo "1. Review the diagnostics above"
echo "2. Check Xcode console logs for Keychain operations"
echo "3. Verify test scenarios in docs/keychain-persistence-testing-guide.md"
echo ""
echo "If all tests pass, commit and push:"
echo "  git push origin release/v1.2"
echo ""
echo "If tests fail, share this diagnostic output with the team."
