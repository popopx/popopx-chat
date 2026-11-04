#!/bin/bash
set -euo pipefail

echo "=== Platform Verification ==="
echo ""

failed=0
for f in /Users/elliot/POPOPX/popopx-chat/apps/ios/Libraries/sim/*.a; do
  if [ ! -f "$f" ]; then
    continue
  fi
  
  filename=$(basename "$f")
  size=$(du -h "$f" | cut -f1)
  lipo_info=$(lipo -info "$f" 2>&1 || echo "no lipo info")
  
  echo "$filename: $size, $lipo_info"
  
  # Extract platform information
  platforms=$( { otool -l "$f" 2>/dev/null || true; } | awk '$1 == "platform" {print $2}' | sort | uniq -c)
  
  if [ -z "$platforms" ]; then
    echo "  ⚠ no LC_BUILD_VERSION found"
  else
    echo "  Platforms:"
    echo "$platforms" | sed 's/^/    /'
    
    # Check if all platforms are 7 (IOSSIMULATOR)
    invalid=$(echo "$platforms" | awk 'NF {print $2}' | grep -vE '^(7|IOSSIMULATOR)$' || true)
    
    if [ -n "$invalid" ]; then
      echo "  ❌ ERROR: $filename has objects for a platform other than the iOS simulator"
      echo "     Invalid platforms: $invalid"
      failed=1
    else
      echo "  ✓ All objects are IOSSIMULATOR (platform 7)"
    fi
  fi
  echo ""
done

if [ $failed -eq 1 ]; then
  echo "=== VERIFICATION FAILED ==="
  exit 1
else
  echo "=== VERIFICATION PASSED ==="
  exit 0
fi
