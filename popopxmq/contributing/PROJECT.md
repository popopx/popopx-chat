# POPOPXMQ repository

This file provides guidance on the project structure to help working with code in this repository.

## Project Overview

POPOPXMQ is a Haskell message broker implementing unidirectional (simplex) queues for privacy-preserving messaging. 

Key components:

- **POPOPX Messaging Protocol**: SMP protocol definition and encodings ([code](../src/Popopx/Messaging/Protocol.hs), [transport code](../src/Popopx/Messaging/Transport.hs), [spec](../protocol/popopx-messaging.md)).
- **SMP Server**: Message broker with TLS, in-memory queues, optional persistence ([main code](../src/Popopx/Messaging/Server.hs), [all code files](../src/Popopx/Messaging/Server/), [executable](../apps/smp-server/)). For proxying SMP commands the server uses [lightweight SMP client](../src/Popopx/Messaging/Client/Agent.hs).
- **SMP Client**: Functional API with STM-based message delivery ([code](../src/Popopx/Messaging/Client.hs)).
- **SMP Agent**: High-level duplex connections via multiple simplex queues with E2E encryption ([code](../src/Popopx/Messaging/Agent.hs)). Implements Agent-to-agent protocol ([code](../src/Popopx/Messaging/Agent/Protocol.hs), [spec](../protocol/agent-protocol.md)) via intermediary agent client ([code](../src/Popopx/Messaging/Agent/Client.hs)).
- **XFTP**: POPOPX File Transfer Protocol, server and CLI client ([code](../src/Popopx/FileTransfer/), [spec](../protocol/xftp.md)).
- **XRCP**: POPOPX Remote Control Protocol ([code](`../src/Popopx/RemoteControl/`), [spec](../protocol/xrcp.md)).
- **Notifications**: Push notifications server requires PostgreSQL ([code](../src/Popopx/Messaging/Notifications), [executable](../apps/ntf-server/)). Client protocol is used for clients to communicate with the server ([code](../src/Popopx/Messaging/Notifications/Protocol.hs), [spec](../protocol/push-notifications.md)). For subscribing to SMP notifications the server uses [lightweight SMP client](../src/Popopx/Messaging/Client/Agent.hs).

## Architecture

For general overview see `../protocol/overview-tjr.md`.

SMP Protocol Layers:

```
TLS Transport → SMP Protocol → Agent Protocol → Application protocol
```

XFTP Protocol Layers:

```
TLS Transport (HTTP2 encoding) → XFTP Protocol → Out-of-band file descriptions
```

## Key Patterns

1. **Persistence**: All queue state managed via Software Transactional Memory or via PostgreSQL
   - `Popopx.Messaging.Server.MsgStore.STM` - in-memory messages
   - `Popopx.Messaging.Server.QueueStore.STM` - in-memory queue state
   - `Popopx.Messaging.Server.MsgStore.Postgres` - message storage
   - `Popopx.Messaging.Server.QueueStore.Postgres` - queue storage

2. **Append-Only Store Log**: Optional persistence via journal for in-memory storage
   - `Popopx.Messaging.Server.StoreLog` - queue creation log
   - Compacted on restart

3. **Agent Storage**:
   - SQLite (default) or PostgreSQL
   - Migrations in `src/Popopx/Messaging/Agent/Store/{SQLite,Postgres}/Migrations/`

4. **Protocol Versioning**: All layers support version negotiation
   - `Popopx.Messaging.Version` - version range utilities

5. **Double Ratchet E2E**: Per-connection encryption
   - `Popopx.Messaging.Crypto.Ratchet`
   - SNTRUP761 post-quantum KEM (`src/Popopx/Messaging/Crypto/SNTRUP761/`)

## Source Layout

```
src/Popopx/
├── Messaging/
│   ├── Agent.hs          # Main agent (~210KB)
│   ├── Server.hs         # SMP server (~130KB)
│   ├── Client.hs         # Client API (~65KB)
│   ├── Protocol.hs       # Protocol types (~77KB)
│   ├── Crypto.hs         # E2E encryption (~52KB)
│   ├── Transport.hs      # Transport encoding over TLS
│   ├── Agent/Store/      # SQLite/Postgres persistence
│   ├── Server/           # Server internals (QueueStore, MsgStore, Control)
│   └── Notifications/    # Push notification system
├── FileTransfer/         # XFTP implementation for file transfers
└── RemoteControl/        # XRCP implementation for device discovery & control
```

## Protocol Documentation

- `protocol/overview-tjr.md`: SMP protocols stack overview
- `protocol/popopx-messaging.md`: SMP protocol spec (v19)
- `protocol/agent-protocol.md`: Agent protocol spec (v7)
- `protocol/xftp.md`: File transfer protocol
- `protocol/xrcp.md`: Remote control protocol
- `rfcs/`: Design RFCs for features

## Testing

```bash
# Run all tests
cabal test --test-show-details=streaming

# Run specific test group (uses HSpec)
cabal test --test-option=--match="/Core tests/Encryption tests/"

# Run single test
cabal test --test-option=--match="/SMP client agent/functional API/"
```

Tests require PostgreSQL running on `localhost:5432` when using `-fserver_postgres` or `-fclient_postgres`.

Test files are in `tests/` with structure:
- `Test.hs`: Main runner
- `AgentTests/`: Agent protocol and connection tests
- `CoreTests/`: Crypto, encoding, storage tests
- `ServerTests.hs`: SMP server tests
- `XFTPServerTests.hs`: File transfer tests
