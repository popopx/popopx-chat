[![build](https://github.com/popopx/popopx-chat/actions/workflows/build.yml/badge.svg?branch=stable)](https://github.com/popopx/popopx-chat/actions/workflows/build.yml)
[![GitHub downloads](https://img.shields.io/github/downloads/popopx/popopx-chat/total)](https://github.com/popopx/popopx-chat/releases)
[![GitHub release](https://img.shields.io/github/v/release/popopx/popopx-chat)](https://github.com/popopx/popopx-chat/releases)

# POPOPX Chat

Privacy-focused messaging platform with no user identifiers of any kind - 100% private by design.

## Features

- No user identifiers - not even random numbers
- Double ratchet end-to-end encryption with post-quantum resistance
- Additional encryption layer for transport
- Mobile apps for iOS (SwiftUI) and Android (Kotlin Multiplatform)
- Terminal CLI client on Linux, MacOS, Windows
- Chat bots and directory services
- Node.js, Python, and WebRTC packages

## Install

### Terminal CLI

```sh
curl -o- https://raw.githubusercontent.com/popopx/popopx-chat/stable/install.sh | bash
```

Then run `popopx-chat` from your terminal.

## Project Structure

```
popopx-chat/
├── src/                    # Haskell core library (Popopx.Chat.*)
├── apps/
│   ├── popopx-chat/        # Main chat server/CLI
│   ├── popopx-bot/         # Simple chat bot
│   ├── popopx-bot-advanced/# Advanced chat bot
│   ├── popopx-broadcast-bot/  # Broadcast bot
│   ├── popopx-directory-service/  # Directory service
│   └── popopx-support-bot/ # Support bot (Node.js)
├── packages/
│   ├── popopx-chat-nodejs/ # Node.js bindings
│   ├── popopx-chat-python/ # Python bindings
│   ├── popopx-chat-client/ # TypeScript client
│   └── popopx-chat-webrtc/ # WebRTC support
├── tests/                  # Test suite
├── scripts/                # Build and utility scripts
└── install.sh              # CLI installer
```

## Build

### Haskell Core

```bash
cabal build          # Build all
cabal test           # Run tests
cabal build --flag swift           # Enable Swift JSON format
cabal build --flag client_library  # Client-only build
```

## Architecture

POPOPX is a client-server network using redundant, disposable message relay nodes to asynchronously pass messages via unidirectional message queues, providing recipient and sender anonymity.

Key components:
- **Haskell core library**: Cryptography, messaging protocol, FFI exports
- **SMP protocol**: SimpleX Messaging Protocol for queue-based message delivery
- **XFTP protocol**: End-to-end encrypted file transfer
- **Double ratchet**: Signal-compatible E2E encryption with post-quantum key exchange
- **No identifiers**: Pairwise per-queue identifiers instead of user IDs

## Privacy & Security

- End-to-end encryption with double ratchet (forward secrecy, break-in recovery)
- Post-quantum resistant key exchange
- No user identifiers - protects metadata and contact graph
- Local database encryption with passphrase
- Transport isolation per user profile
- TLS 1.2/1.3 only with strong cipher suites
- Content padding to prevent message size attacks
- Optional Tor support for server connections

## For Developers

- Create chat bots in Haskell: see [apps/popopx-bot/](./apps/popopx-bot/) and [apps/popopx-bot-advanced/](./apps/popopx-bot-advanced/)
- Use Node.js/Python/TypeScript packages for integrations
- Run terminal CLI for scripting: `popopx-chat --help`
- Bot API reference: [bots/README.md](./bots/README.md)

## ⚖️ 二次开发与修改声明 (Derivative Work)

本项目基于原开源项目 [SimpleX Chat](https://github.com/simplex-chat/simplex-chat)（作者：SimpleX Team）进行二次开发。

根据 **GNU Affero General Public License v3 (AGPL v3)** 协议要求，特此声明以下修改信息：
- **二次开发者**：POPOPX Team (chat@popopx.chat)
- **修改起始时间**：2026年07月

本衍生版本同样严格在 GNU AGPL v3 协议下开源。

## License

This software is licensed under the GNU Affero General Public License version 3 (AGPLv3). See the [LICENSE](./LICENSE) file for details.

The POPOPX and POPOPX Chat name, logo, associated branding materials, and application and website graphic assets are not covered by this license and are subject to the terms outlined in the [ASSETS_LICENSE](./assets/ASSETS_LICENSE.md) file.
