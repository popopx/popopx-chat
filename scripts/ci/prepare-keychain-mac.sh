#!/bin/bash

security create-keychain -p "" popopx.keychain
security set-keychain-settings -u popopx.keychain
security add-certificates -k popopx.keychain "Developer ID Application: POPOPX Chat Ltd (5NN7GUYB6T).cer"
security add-certificates -k popopx.keychain "Developer ID Certification Authority.cer"
# Private key with access from any app
security import "POPOPX Chat.p12" -P "" -k popopx.keychain -A
# Public key
security import "POPOPX Chat.pem" -k popopx.keychain
