# POPOPX iOS

## Derivative Work Notice (AGPL v3)

This project is a derivative work of [simplex-chat](https://github.com/simplex-chat/simplex-chat) (author: [simplex.chat](https://simplex.chat)).

In compliance with the **GNU Affero General Public License v3 (AGPL v3)**, the following modification information is provided:

- **Modified by**: POPOPX Team (<chat@popopx.xyz>)
- **Modification start date**: July 2026

This derivative version is also strictly open-sourced under the GNU AGPL v3 license.

### Principal modifications

- Rebranded from SimpleX Chat to POPOPX
- Added quantum-resistant cryptographic protocols (BBS signatures, blst)
- Added dual-transport architecture: internet + BLE mesh (via bitchat)
- Added unified identity management across multiple devices
- Added token-based economy and badge system
- Added encrypted document sharing
- Added community features and bot platform
- Added Nostr relay bridge
- Merged upstream simplex-chat iOS 7.1 updates (2026-10-08)

All modified source files carry prominent modification notices with dates, as required by AGPL v3 Section 5(a). See [NOTICE](NOTICE) for full details.

---

POPOPX is a privacy-focused messaging app built as a derivative of [simplex-chat](https://github.com/simplex-chat/simplex-chat), with additional features including quantum-resistant cryptography, dual-transport architecture (BLE mesh + internet), unified identity management, and token-based monetization.

## Features

- End-to-end encrypted messaging and calls
- Quantum-resistant cryptographic protocols
- Dual-transport: internet + BLE mesh (via bitchat)
- Unified identity across multiple devices
- Token-based economy
- Encrypted document sharing
- Bot platform
- Nostr relay bridge

## Building from Source

### Requirements

- Xcode 15+
- iOS 17.6+ SDK
- Swift 5.9+

### Steps

```bash
git clone https://github.com/popopx/popopx-ios.git
cd popopx-ios
open POPOPX.xcodeproj
```

Build and run the `POPOPX (iOS)` scheme in Xcode.

## Architecture

- **POPOPXSwitch** — Core framework (FFI bindings, types, file utilities)
- **Shared/** — App logic, views, models
- **POPOPX NSE** — Notification Service Extension
- **POPOPX SE** — Share Extension
- **Libraries/** — Prebuilt Haskell FFI libraries

## Source Code Availability (AGPL v3 Section 13)

This software is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). Under Section 13, if you modify this software and operate it as a network service, you must make the complete corresponding source code available to users interacting with it remotely.

### How to obtain source code

1. **Download**: https://github.com/popopx/popopx-ios
2. **Build from source**: See "Building from Source" section above
3. **Request via email**: chat@popopx.xyz

### Downstream compliance

If you modify and distribute this software, or deploy it as a network service, you are required under AGPL v3 to:

- Offer the corresponding source code to your users
- Include prominent notices stating that you modified the files
- Preserve all copyright notices and the license text
- Include the NOTICE file with any distribution

## License

Licensed under the [GNU Affero General Public License v3.0](LICENSE).

```
POPOPX iOS
Copyright (C) 2025-2026 POPOPX Team

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.
```

### Original work

POPOPX is a derivative of [simplex-chat](https://github.com/simplex-chat/simplex-chat), Copyright (C) 2020-2025 simplex.chat, also licensed under AGPL-3.0.

See [NOTICE](NOTICE) for full attribution details.

### Third-party components

- **bitchat** by Jack Dorsey — The Unlicense (Public Domain)
- **blst** — Apache 2.0
- **libbbs** — Apache 2.0
- **WebRTC** — Google WebRTC (BSD license)
