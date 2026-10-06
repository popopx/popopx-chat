#!/bin/sh
set -eu

# Copies generated iOS assets into PopopxAssets.xcassets.
# Intended to run as an Xcode Run Script build phase.
# Skips silently if POPOPX_ASSETS is not in SWIFT_ACTIVE_COMPILATION_CONDITIONS
# or if the source directory is not found.
#
# The source path is resolved in order:
#   1. Command-line argument
#   2. POPOPX_ASSETS_DIR build setting (set in Local.xcconfig)
#   3. No default — skips if neither is set
#
# Manual usage: ./scripts/copy-assets.sh path/to/assets

# Skip if POPOPX_ASSETS flag is not set (unless run manually outside Xcode)
if [ -n "${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-}" ]; then
  case " $SWIFT_ACTIVE_COMPILATION_CONDITIONS " in
    *" POPOPX_ASSETS "*) ;;
    *) exit 0 ;;
  esac
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$SCRIPT_DIR/../../apps/ios/Shared/PopopxAssets.xcassets"

ASSETS_ROOT="${1:-${POPOPX_ASSETS_DIR:-}}"
if [ -z "$ASSETS_ROOT" ]; then
  # Skip silently if no assets directory configured (normal for local development)
  exit 0
fi

SRC_DIR="$ASSETS_ROOT/ios/Assets.xcassets"

if [ ! -d "$SRC_DIR" ]; then
  echo "warning: source assets not found: $SRC_DIR (run resize.sh first)" >&2
  exit 0
fi

# Remove old imagesets but keep root Contents.json
find "$IOS_DIR" -name "*.imageset" -type d -exec rm -rf {} + 2>/dev/null || true

# Copy imagesets
for imageset in "$SRC_DIR"/*.imageset; do
  [ -d "$imageset" ] || continue
  cp -r "$imageset" "$IOS_DIR/"
  echo "Copied $(basename "$imageset")"
done

echo "Done. Assets copied to $IOS_DIR"
