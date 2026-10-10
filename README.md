# PopopX Chat

<p align="center">
  <strong>Privacy-focused messaging platform with no user identifiers - 100% private by design</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#build-from-source">Build from Source</a> •
  <a href="#documentation">Documentation</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

---

## About

PopopX Chat is a privacy-focused messaging platform forked from SimpleX Chat, featuring comprehensive rebranding and enhanced customization. Built on the foundation of zero user identifiers, PopopX Chat ensures complete privacy by design.

**Key Differences from SimpleX Chat:**
- Complete rebranding from SimpleX to PopopX
- Custom naming conventions throughout the codebase
- Enhanced modularity and extensibility
- Active community-driven development

## Features

### Privacy & Security
- 🕵️ **No User Identifiers**: No phone numbers, email addresses, or any persistent identifiers
- 🔐 **End-to-End Encryption**: Double ratchet protocol with additional encryption layers
- 🛡️ **Metadata Protection**: Protects who you talk to and when
- 🔒 **Private by Design**: Architecture built around privacy from the ground up

### Communication
- 💬 **Direct Messages**: Secure one-to-one conversations
- 👥 **Group Chats**: Private group messaging with fine-grained control
- 📞 **Voice & Video Calls**: Encrypted calls through the platform
- 📁 **File Sharing**: Secure file transfer with end-to-end encryption
- 🤖 **Bot Support**: Extensible bot framework for automation

### Platform Support
- 📱 **iOS**: Native iOS application
- 🤖 **Android**: Native Android application  
- 💻 **Desktop**: Cross-platform terminal/CLI application
- 🌐 **Web**: Web-based interface (planned)

### Advanced Features
- 🔗 **PopopX Names**: Custom naming system for users and groups
- 🎭 **Incognito Mode**: Temporary identities for enhanced privacy
- ⏱️ **Disappearing Messages**: Self-destructing messages with customizable timers
- 🔍 **Search**: Full-text search across conversations
- 🏷️ **Chat Tags**: Organize conversations with custom tags
- 📊 **Message Reactions**: Express reactions to messages
- 🔔 **Mentions**: Mention specific users in group chats

## Installation

### Pre-built Binaries

#### macOS
```bash
# Using Homebrew (coming soon)
brew install popopx-chat

# Or download from releases
curl -LO https://github.com/popopx/popopx-chat/releases/latest/download/popopx-chat-macos
chmod +x popopx-chat-macos
./popopx-chat-macos
```

#### Linux
```bash
# Using package manager (coming soon)
sudo apt install popopx-chat  # Debian/Ubuntu
sudo dnf install popopx-chat  # Fedora/RHEL

# Or download binary
curl -LO https://github.com/popopx/popopx-chat/releases/latest/download/popopx-chat-linux
chmod +x popopx-chat-linux
./popopx-chat-linux
```

#### Windows
```powershell
# Download from releases
Invoke-WebRequest -Uri "https://github.com/popopx/popopx-chat/releases/latest/download/popopx-chat-windows.exe" -OutFile "popopx-chat.exe"
.\popopx-chat.exe
```

### Mobile Apps

#### iOS
- App Store: [PopopX Chat](https://apps.apple.com/app/popopx-chat) (coming soon)
- TestFlight: [Join beta](https://testflight.apple.com/join/XXXXX) (coming soon)

#### Android
- Google Play: [PopopX Chat](https://play.google.com/store/apps/details?id=chat.popopx.app) (coming soon)
- F-Droid: [PopopX Chat](https://f-droid.org/packages/chat.popopx.app) (coming soon)
- Direct APK: [Download](https://github.com/popopx/popopx-chat/releases/latest/download/popopx-chat.apk)

## Build from Source

### Prerequisites

- **Haskell**: GHC 9.6.3 or later
- **Cabal**: 3.10 or later
- **Nix**: 2.18 or later (optional, for reproducible builds)
- **SQLite**: 3.35 or later
- **OpenSSL**: 3.0 or later

### Quick Build

```bash
# Clone the repository
git clone https://github.com/popopx/popopx-chat.git
cd popopx-chat

# Build all components
cabal build

# Run the chat application
cabal run popopx-chat
```

### Detailed Build Instructions

#### Haskell Core Library

```bash
# Build the core library
cabal build lib:popopx-chat

# Build specific executables
cabal build exe:popopx-chat
cabal build exe:popopx-bot
cabal build exe:popopx-directory-service

# Run tests
cabal test
```

#### iOS Library

```bash
# Build iOS simulator library
nix build .#popopx-chat-lib-popopx-chat

# The library will be available at ./result-ios-sim
```

#### Desktop Applications

```bash
# Build all desktop applications
cabal build all

# Run specific applications
cabal run popopx-chat
cabal run popopx-bot
cabal run popopx-directory-service
```

### Build Options

```bash
# Enable Swift JSON format (for iOS)
cabal build --flag swift

# Build client library only (no server/CLI)
cabal build --flag client_library

# Use PostgreSQL instead of SQLite
cabal build --flag client_postgres
```

## Documentation

### User Guides
- [Getting Started](docs/guide/README.md)
- [Making Connections](docs/guide/making-connections.md)
- [Chat Profiles](docs/guide/chat-profiles.md)
- [Audio/Video Calls](docs/guide/audio-video-calls.md)
- [App Settings](docs/guide/app-settings.md)

### Developer Documentation
- [Build Commands](docs/BUILD_COMMANDS.md) - Complete build and compilation guide
- [Architecture Overview](docs/ARCHITECTURE.md) - System architecture
- [API Reference](docs/API.md) - API documentation
- [Bot Development](docs/BOTS.md) - Creating bots for PopopX Chat

### Protocol Documentation
- [Chat Protocol](docs/protocol/simplex-chat.md) - Core protocol specification
- [Channels Protocol](docs/protocol/channels-protocol.md) - Channel implementation
- [Names Overview](docs/protocol/names-overview.md) - PopopX names system

### Project Documentation
- [Changelog](CHANGELOG.md) - Version history
- [Changes Log](docs/CHANGES_2026_10_10.md) - Recent changes
- [Naming Consistency](docs/NAMING_CONSISTENCY_CHECK.md) - Rebranding verification

## Project Structure

```
popopx-chat/
├── src/                          # Haskell source code
│   └── Popopx/Chat/             # Core chat library
├── apps/                         # Applications
│   ├── popopx-chat/             # Main chat application
│   ├── popopx-bot/              # Simple bot
│   ├── popopx-bot-advanced/     # Advanced bot
│   ├── popopx-directory-service/ # Directory service
│   ├── popopx-badge-service/    # Badge service
│   ├── popopx-broadcast-bot/    # Broadcast bot
│   ├── popopx-calculator-bot/   # Calculator bot (TypeScript)
│   ├── popopx-support-bot/      # Support bot (TypeScript)
│   └── popopx-support-bot-light/ # Lightweight support bot (Python)
├── tests/                        # Test suite
├── packages/                     # Language bindings
│   ├── popopx-chat-python/      # Python library
│   └── popopx-chat-nodejs/      # Node.js library
├── apps/ios/                     # iOS application
├── docs/                         # Documentation
└── scripts/                      # Build and utility scripts
```

## Testing

### Running Tests

```bash
# Run all tests
cabal test

# Run specific test suite
cabal test test:popopx-chat-test

# Run with verbose output
cabal test --test-show-details=direct
```

### Test Coverage

The test suite includes:
- Unit tests for core functionality
- Integration tests for chat operations
- Protocol compliance tests
- Bot functionality tests
- Directory service tests

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`cabal test`)
5. Format code (`fourmolu --mode inplace <file>`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Code Style

- **Haskell**: Follow [fourmolu](https://github.com/fourmolu/fourmolu) formatting
- **Swift**: Follow existing patterns in `apps/ios/Shared/`
- **TypeScript/JavaScript**: Follow existing patterns
- **Python**: Follow PEP 8

### Reporting Issues

- Use [GitHub Issues](https://github.com/popopx/popopx-chat/issues)
- Provide detailed description and steps to reproduce
- Include system information and version
- Attach logs if relevant

## Community

- **GitHub Discussions**: [Join the conversation](https://github.com/popopx/popopx-chat/discussions)
- **Reddit**: [r/PopopXChat](https://www.reddit.com/r/PopopXChat) (coming soon)
- **Twitter**: [@PopopXChat](https://twitter.com/PopopXChat) (coming soon)
- **Matrix**: [#popopx-chat:matrix.org](https://matrix.to/#/#popopx-chat:matrix.org) (coming soon)

## Security

### Security Audits

This project is based on SimpleX Chat, which has undergone security audits:
- [Trail of Bits Audit (2022)](https://simplex.chat/blog/20221108-simplex-chat-v4.2-security-audit-new-website.html)

### Reporting Security Issues

If you discover a security vulnerability, please:
1. **DO NOT** open a public issue
2. Email: security@popopx.chat (coming soon)
3. Include detailed description and reproduction steps
4. Allow reasonable time for response before public disclosure

## License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)** - see the [LICENSE](LICENSE) file for details.

### Original Work

PopopX Chat is a fork of [SimpleX Chat](https://github.com/simplex-chat/simplex-chat), originally developed by simplex.chat.

**Original Copyright**: © 2020-2022 simplex.chat  
**Modifications Copyright**: © 2026 POPOPX Team

### Third-Party Dependencies

This project uses various open-source dependencies. See [NOTICE](NOTICE) for details.

## Acknowledgments

- **SimpleX Chat Team**: For the original implementation and protocol design
- **Trail of Bits**: For security audit
- **Privacy Guides**: For recommendations
- **Community Contributors**: For feedback and improvements

## Links

- **Website**: [popopx.chat](https://popopx.chat) (coming soon)
- **GitHub**: [github.com/popopx/popopx-chat](https://github.com/popopx/popopx-chat)
- **Documentation**: [docs.popopx.chat](https://docs.popopx.chat) (coming soon)
- **Blog**: [blog.popopx.chat](https://blog.popopx.chat) (coming soon)

---

<p align="center">
  <strong>Privacy is not a feature, it's a fundamental right.</strong>
</p>

<p align="center">
  Made with ❤️ by the PopopX community
</p>
