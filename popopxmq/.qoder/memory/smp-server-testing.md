# SMP Server Testing and Configuration

## Date: 2026-10-18

## Server Status
- ✓ smp-server v7.1.0.12 running successfully
- PID: 8640
- Listening on port 5223 (TLS)
- Server address: `smp://j2BrnthuQxqZEVq0Tcm90UfVVMnlo4du3QtvAPNIkcI=@localhost:5223`

## Configuration Changes Made

### File: /etc/opt/popopx/smp-server.ini

#### TRANSPORT Section
```ini
host = localhost          # Changed from <hostnames>
port = 5223               # Changed from 5223,443
```

#### STORE_LOG Section
```ini
enable = off              # Disabled due to segfault issues
store_queues = memory
store_messages = memory
restore_messages = off    # Disabled
log_stats = off           # Disabled (can be enabled safely)
```

#### WEB Section
```ini
# static_path = /var/opt/popopx/www  # Commented out
# https = 443                         # Commented out
# cert = /etc/opt/popopx/web.crt      # Commented out
# key = /etc/opt/popopx/web.key       # Commented out
```

## Issues Encountered and Resolved

### 1. Segmentation Fault (SIGSEGV)
- **Symptom**: Server crashed with NULL pointer dereference during startup
- **Location**: Store log restoration process
- **Root Cause**: Corrupted or incompatible store log files
- **Solution**: Reinitialized server with `smp-server init`, disabled store log

### 2. Host Configuration
- **Problem**: `host = <hostnames>` placeholder caused issues
- **Solution**: Changed to `host = localhost`

### 3. Port Binding Issues
- **Problem**: Port 443 required root permissions
- **Solution**: Changed to only use port 5223

### 4. Missing HTTPS Credentials
- **Problem**: Server tried to load web.crt/web.key that didn't exist
- **Solution**: Disabled WEB HTTPS configuration

### 5. Store Log Parsing Errors
- **Problem**: Empty or corrupted log files caused parsing failures
- **Error**: `Error parsing log: Failed reading: empty`
- **Solution**: Disabled store log (`enable = off`)

## STORE_LOG Analysis

### Current Status: DISABLED
- **Impact**: Server restart loses all queues and messages
- **Suitable for**: Testing environment only
- **Not suitable for**: Production environment

### log_stats Setting
- **Current**: `off`
- **Impact if enabled**: Minimal (daily CSV file, ~1KB/day)
- **Recommendation**: Can be safely enabled for monitoring
- **File**: `/var/opt/popopx/smp-server-stats.daily.log`

### To Enable Persistence (Production)
```ini
[STORE_LOG]
enable = on
restore_messages = on
log_stats = on  # Optional, for monitoring
```
**Warning**: May encounter segfault issues with corrupted logs

## Testing Results

### TLS Connection Test
```
✓ CONNECTED
✓ TLSv1.3
✓ Cipher: TLS_CHACHA20_POLY1305_SHA256
✓ Self-signed certificate (expected for testing)
```

### Server Process
```
PID: 8640
Status: Sl (multi-threaded, background)
Memory: 28MB RSS / 1GB VSZ
CPU: 0.1%
Uptime: Running since 13:49:03
```

## File Locations

### Configuration
- **Config**: `/etc/opt/popopx/smp-server.ini`
- **Certificates**: `/etc/opt/popopx/server.crt`, `server.key`, `ca.crt`
- **Fingerprint**: `/etc/opt/popopx/fingerprint`

### Data (when enabled)
- **Store log**: `/var/opt/popopx/smp-server-store.log`
- **Messages**: `/var/opt/popopx/smp-server-messages.log`
- **Notifications**: `/var/opt/popopx/smp-server-ntfs.log`
- **Statistics**: `/var/opt/popopx/smp-server-stats.daily.log`
- **Web files**: `/var/opt/popopx/www/`

### Binary
- **Path**: `/home/ubuntu/popopxmq/dist-newstyle/build/x86_64-linux/ghc-9.6.3/popopxmq-7.1.0.12/x/smp-server/build/smp-server/smp-server`

## Commands

### Start Server
```bash
/home/ubuntu/popopxmq/dist-newstyle/build/x86_64-linux/ghc-9.6.3/popopxmq-7.1.0.12/x/smp-server/build/smp-server/smp-server start
```

### Check Status
```bash
ps aux | grep smp-server
ss -tlnp | grep 5223
```

### Test Connection
```bash
openssl s_client -connect localhost:5223 -brief
```

### Reinitialize (if needed)
```bash
smp-server delete  # Requires confirmation
smp-server init -y --no-password --disable-store-log
```

## Known Issues

1. **Version Compatibility**: Store logs from v7.1.0.11 incompatible with v7.1.0.12
2. **Segfault**: Occurs with corrupted store logs during restoration
3. **No Persistence**: Current config loses all data on restart
4. **Web Interface**: Disabled (requires HTTPS certificates)

## Recommendations

### For Testing
Current configuration is acceptable.

### For Production
1. Fix STORE_LOG segfault issues
2. Enable persistence: `enable = on`, `restore_messages = on`
3. Enable statistics: `log_stats = on`
4. Configure proper HTTPS certificates for web interface
5. Set up proper backup strategy
6. Consider PostgreSQL backend instead of file-based storage

## Related Code

### Key Files
- `src/Popopx/Messaging/Server.hs` - Main server logic
- `src/Popopx/Messaging/Server/Env/STM.hs` - Environment setup
- `src/Popopx/Messaging/Server/Main.hs` - CLI and configuration
- `src/Popopx/Messaging/Server/StoreLog/ReadWrite.hs` - Store log I/O
- `src/Popopx/Messaging/Transport/Server.hs` - TCP/TLS server

### Recent Commits
```
a1c4885 Sync upstream v7.1.0.12: fix queue store map cleanup on delete
```
