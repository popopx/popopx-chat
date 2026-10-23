# POPOPXMQ

[![GitHub build](https://github.com/popopx/popopxmq/actions/workflows/build.yml/badge.svg)](https://github.com/popopx/popopxmq/actions/workflows/build.yml)
[![GitHub release](https://img.shields.io/github/v/release/popopx/popopxmq)](https://github.com/popopx/popopxmq/releases)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

POPOPXMQ is a message broker for managing unidirectional (simplex) message queues, providing secure and private message transmission over public networks.

> This is a fork of [simplexmq](https://github.com/simplex-chat/simplexmq), maintained and developed by the [POPOPX](https://popopx.xyz) team.

## Secondary Development Declaration

This project is a derivative work based on the original open-source project [simplexmq](https://github.com/simplex-chat/simplexmq) by [simplex.chat](https://github.com/simplex-chat).

In accordance with the **GNU Affero General Public License v3 (AGPL v3)**, the following modification information is hereby declared:

- **Secondary Developer**: POPOPX Team (<chat@popopx.xyz>)
- **Modification Start Date**: July 2026

This derivative version is also openly released under the GNU AGPL v3 license.

## Core Features

- **Unidirectional Queue Management** - Message broker based on simplex queues
- **End-to-End Security** - TLS encrypted transport with offline certificate protection
- **Lightweight Deployment** - Supports low-power/low-memory devices
- **High Concurrency** - Robust concurrency model based on Haskell STM
- **Simple Protocol** - Only 10 client commands and 8 server responses
- **Persistent Storage** - In-memory persistence with optional append-only log

## Components

### SMP Server (Message Server)

The SMP server is the core component of POPOPXMQ, responsible for managing message queues and handling client connections.

**Key Features:**
- Message queue creation, management, and deletion
- TLS encrypted transport
- Optional message persistence
- Queue log compaction
- Undelivered message save and restore

**System Requirements:**
- Linux system (Ubuntu 20.04/22.04/24.04 supported)
- OpenSSL library
- x86_64 architecture

**Quick Start:**

```bash
# Initialize server
sudo smp-server init -n your.domain.com

# Start server
sudo smp-server start

# View help
smp-server --help
```

**Server Address Format:**
```
smp://<fingerprint>@<hostname>[:5223]
```

### XFTP Server (File Transfer Server)

XFTP server provides secure file transfer services with support for large file chunked transmission.

```bash
# Initialize XFTP server
sudo xftp-server init -n your.domain.com

# Start server
sudo xftp-server start
```

### XFTP Client (File Transfer Client)

XFTP client is used to interact with XFTP servers for uploading and downloading files.

```bash
# Check version
xftp --version

# View help
xftp --help
```

## Installation

### Method 1: Using Installation Script (Recommended)

```bash
curl -sSf https://raw.githubusercontent.com/popopx/popopxmq/stable/install.sh | sudo sh
```

The installation script will:
1. Download latest binaries from GitHub releases
2. Create server directories and configuration
3. Setup system users
4. Create systemd services
5. Install update and uninstall scripts

### Method 2: Building from Source

**Requirements:**
- GHC 9.6.6
- Cabal 3.16+
- libgmp-dev
- libssl-dev

**Build Steps:**

```bash
# Install GHC and Cabal
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
export PATH="$HOME/.ghcup/bin:$PATH"
ghcup install ghc 9.6.6
ghcup set ghc 9.6.6

# Install system dependencies
sudo apt-get install -y libgmp-dev libssl-dev

# Clone repository
git clone https://github.com/popopx/popopxmq.git
cd popopxmq

# Update dependencies and build
cabal update
cabal build all

# Executable locations
ls dist-newstyle/build/x86_64-linux/ghc-9.6.6/popopxmq-7.0.1.0/x/
```

## Configuration

### SMP Server Configuration

Configuration file location: `/etc/opt/popopx/smp-server.ini`

**Main Configuration Options:**

```ini
[main]
host: *                    # Listen address
port: 5223                 # Listen port
log_file: /var/opt/popopx/smp-server.log

[STORE_LOG]
enable = on               # Enable storage log
log_stats = off           # Statistics log
restore_messages = on     # Restore undelivered messages

[CREDENTIALS]
ca_certificate_file: /etc/opt/popopx/ca.crt
private_key_file: /etc/opt/popopx/server.key
certificate_file: /etc/opt/popopx/server.crt
```

### Security Recommendations

1. **Protect CA Private Key** - CA private key (`/etc/opt/popopx/ca.key`) should be stored securely and deleted from the server
2. **Use Strong Passwords** - Set strong passwords for system users
3. **Firewall Configuration** - Only open necessary ports (default 5223)
4. **Regular Updates** - Use `popopx-servers-update` script for regular updates

## Protocol Documentation

- [SMP Protocol Specification](./protocol/popopx-messaging.md)
- [Agent Protocol Specification](./protocol/agent-protocol.md)

The SMP protocol is inspired by [Redis serialization protocol](https://redis.io/topics/protocol), but simplified.

## Management Scripts

The following management scripts are provided after installation:

```bash
# Update server
sudo popopx-servers-update

# Uninstall server (complete cleanup)
sudo popopx-servers-uninstall

# Stop server
sudo popopx-servers-stopscript
```

## Technical Architecture

POPOPXMQ is implemented in Haskell, leveraging Haskell's Software Transactional Memory (STM) and concurrency primitives:

- **Concurrency Model** - Robust concurrency control based on STM
- **Memory Management** - Efficient in-memory persistence and recovery mechanisms
- **Cryptographic Implementation** - OpenSSL integration with modern encryption algorithms
- **Protocol Design** - Simple and efficient binary protocol

## Version Information

- **Current Version**: 7.0.1.0
- **Protocol Version**: SMP v1
- **Haskell Version**: GHC 9.6.6
- **License**: AGPL-3.0

## Upstream Project

This project is based on [simplexmq](https://github.com/simplex-chat/simplexmq) (v7.0.1.0).

**Original Author**: simplex.chat  
**Copyright**: Copyright 2020-2022 simplex.chat  
**Maintainer**: POPOPX Team (chat@popopx.xyz)

## Links

- **Official Website**: https://popopx.xyz
- **Documentation**: https://popopx.xyz/docs
- **GitHub**: https://github.com/popopx/popopxmq
- **Issue Tracker**: https://github.com/popopx/popopxmq/issues

## License

This project is licensed under the [AGPL-3.0](./LICENSE) License.

## Source Code Availability (AGPL v3 Section 13)

In compliance with the GNU Affero General Public License v3 (AGPL v3) Section 13, the complete source code of this software is made available to all users interacting with it over a network.

You may obtain the source code by:

- **Downloading from GitHub**: https://github.com/popopx/popopxmq
- **Building from source**: See the [Installation](#method-2-building-from-source) section above
- **Requesting source code**: Contact the POPOPX Team at <chat@popopx.xyz>

If you modify and deploy this software as a network service, you are required under AGPL v3 to offer the corresponding source code to your users.

---

**POPOPXMQ** - Secure, Private, and Efficient Unidirectional Message Queue Broker
