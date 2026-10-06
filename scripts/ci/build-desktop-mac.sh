#!/bin/bash

set -e

trap "rm apps/multiplatform/local.properties 2> /dev/null || true; rm local.properties 2> /dev/null || true; rm /tmp/popopx.keychain" EXIT
echo "desktop.mac.signing.identity=Developer ID Application: POPOPX Chat Ltd (5NN7GUYB6T)" >> apps/multiplatform/local.properties
echo "desktop.mac.signing.keychain=/tmp/popopx.keychain" >> apps/multiplatform/local.properties
echo "desktop.mac.notarization.apple_id=$APPLE_POPOPX_NOTARIZATION_APPLE_ID" >> apps/multiplatform/local.properties
echo "desktop.mac.notarization.password=$APPLE_POPOPX_NOTARIZATION_PASSWORD" >> apps/multiplatform/local.properties
echo "desktop.mac.notarization.team_id=5NN7GUYB6T" >> apps/multiplatform/local.properties
echo "$APPLE_POPOPX_SIGNING_KEYCHAIN" | base64 --decode -o /tmp/popopx.keychain

security unlock-keychain -p "" /tmp/popopx.keychain
# Adding keychain to the list of keychains.
# Otherwise, it can find cert but exits while signing with "error: The specified item could not be found in the keychain."
security list-keychains -s `security list-keychains | xargs` /tmp/popopx.keychain
scripts/desktop/build-lib-mac.sh
cd apps/multiplatform
if [ -n "${ASSETS_DIR:-}" ]; then
  set -- -Ppopopx.assets.dir="$ASSETS_DIR"
else
  set --
fi
./gradlew "$@" packageDmg
./gradlew "$@" notarizeDmg
