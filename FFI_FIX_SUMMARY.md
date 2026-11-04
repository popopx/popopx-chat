# FFI 接口检查总结

## 检查日期
2026-10-30

## 检查范围
iOS App (`apps/ios/`) 与 Haskell Core (`src/`) 之间的 FFI 接口数据格式一致性

---

## 发现的问题

### ❌ 严重问题（P0 - 立即修复）

#### 1. 发送消息命令参数缺失

**位置**: 
- iOS: `apps/ios/Shared/Model/AppAPITypes.swift:264-268`
- Haskell: `src/Popopx/Chat/Library/Commands.hs:6392`

**问题**:
```swift
// iOS 生成的命令
"/_send {chatRef} live={on|off} ttl={seconds} json {JSON}"
```

```haskell
-- Haskell 期望的命令
"/_send " *> (APISendMessages 
  <$> sendRefP           
  <*> liveMessageP       
  <*> sendMessageTTLP    
  <*> signMessagesP      -- ❌ 缺失
  <*> burnAfterReadP     -- ❌ 缺失
  <*> (" json " *> jsonP))
```

**影响**: 所有消息发送功能失败

**修复**: 
1. 在 `ChatCommand.apiSendMessages` 枚举中添加 `sign: Bool` 和 `burnAfterRead: Int?` 参数
2. 更新命令字符串生成逻辑
3. 更新所有调用点

**预计工作量**: 2-3 小时

---

### ⚠️ 需要验证的问题（P1 - 本周完成）

#### 2. POPOPX 特有命令的 Haskell 解析器

**涉及的命令**:
- 计算购买: `/_get compute balance`, `/_record compute purchase`, `/_get compute purchases`
- BinThere 机器人: `/_get binthere bots`, `/_insert binthere bot`, `/_report binthere bot use`, `/_sync bot directory`

**问题**: iOS 端定义了这些命令，但 Haskell 端可能缺少对应的解析器

**验证方法**:
```bash
grep -n "compute balance\|binthere bot" src/Popopx/Chat/Library/Commands.hs
```

**如果缺失**: 需要在 `Commands.hs` 中添加对应的解析器和 `ChatCommand` 构造函数

**预计工作量**: 4-6 小时

#### 3. 启动聊天命令参数

**位置**: 
- iOS: `apps/ios/Shared/Model/AppAPITypes.swift:243`
- Haskell: `src/Popopx/Chat/Library/Commands.hs:6342-6347`

**问题**: Haskell 支持 `service_requests` 参数，但 iOS 未发送

**验证**: 检查所有 `.startChat` 调用点，确认是否需要添加此参数

**预计工作量**: 1-2 小时

#### 4. 获取聊天列表的 pcc 参数

**位置**: 
- iOS: `apps/ios/Shared/Model/AppAPITypes.swift:253`
- Haskell: `src/Popopx/Chat/Library/Commands.hs:6381-6387`

**问题**: iOS 总是发送 `pcc` 参数，但 Haskell 允许省略

**验证**: 检查 `pcc` 的来源，确认是否可能为 `nil`

**预计工作量**: 1-2 小时

---

## 已验证正确的接口

### ✅ FFI 函数签名

| 函数 | 状态 | 说明 |
|------|------|------|
| `chat_migrate_init_key` | ✅ | 参数类型匹配 |
| `chat_send_cmd_retry` | ✅ | 参数类型匹配 |
| `chat_recv_msg_wait` | ✅ | 参数类型匹配 |
| `chat_close_store` | ✅ | 参数类型匹配 |
| `chat_reopen_store` | ✅ | 参数类型匹配 |
| `chat_parse_markdown` | ✅ | 参数类型匹配 |
| `chat_parse_server` | ✅ | 参数类型匹配 |
| `chat_parse_uri` | ✅ | 参数类型匹配 |
| `chat_password_hash` | ✅ | 参数类型匹配 |
| `chat_valid_name` | ✅ | 参数类型匹配 |
| `chat_json_length` | ✅ | 参数类型匹配 |

### ✅ 基本命令格式

| 命令 | iOS 格式 | Haskell 格式 | 状态 |
|------|---------|-------------|------|
| 显示活跃用户 | `/u` | `("/user" <|> "/u")` | ✅ |
| 创建用户 | `/_create user {JSON}` | `"/_create user " *> ...` | ✅ |
| 列出用户 | `/users` | `"/users"` | ✅ |
| 检查运行状态 | `/_check running` | `"/_check running"` | ✅ |
| 停止聊天 | `/_stop` | `"/_stop"` | ✅ |
| 获取标签 | `/_get tags {userId}` | `"/_get tags " *> ...` | ✅ |
| 获取服务器操作员 | `/_operators` | `"/_operators"` | ✅ |
| 设置服务器操作员 | `/_operators {JSON}` | `"/_operators " *> ...` | ✅ |

### ✅ JSON 编码/解码

| 特性 | iOS | Haskell | 状态 |
|------|-----|---------|------|
| OWSF 格式 | `preprocessOWSF` | `sumTypeJSON` | ✅ |
| 枚举编码 | `RawRepresentable` | `enumJSON` | ✅ |
| 可选字段 | `Optional<T>` | `Maybe a` | ✅ |
| 日期格式 | ISO 8601 | ISO 8601 | ✅ |

### ✅ 内存管理

| 操作 | iOS | Haskell | 状态 |
|------|-----|---------|------|
| 字符串分配 | `cString(using: .utf8)` | `newCStringFromLazyBS` | ✅ |
| 字符串释放 | `free(cjson)` | 调用方负责 | ✅ |
| 数据转换 | `dataFromCString` | `B.packCString` | ✅ |

---

## 修复优先级

### P0（立即 - 今天）
1. ✅ **修复发送消息命令**
   - 更新枚举定义
   - 更新命令字符串生成
   - 更新所有调用点
   - 编写单元测试
   - **预计**: 2-3 小时

### P1（本周）
2. ⏳ **验证 POPOPX 特有命令**
   - 检查 Haskell 解析器
   - 添加缺失的解析器
   - 测试命令执行
   - **预计**: 4-6 小时

3. ⏳ **验证启动聊天命令**
   - 检查参数完整性
   - 如需要，添加 `serviceRequests` 参数
   - **预计**: 1-2 小时

4. ⏳ **验证获取聊天列表命令**
   - 检查 `pcc` 参数处理
   - 如需要，更新命令生成逻辑
   - **预计**: 1-2 小时

### P2（下周）
5. ⏳ **添加命令日志**
   - iOS 端记录所有发送的命令
   - Haskell 端记录所有解析的命令
   - **预计**: 2-3 小时

6. ⏳ **创建端到端测试**
   - 为每个关键命令创建测试用例
   - 验证命令在两端的一致性
   - **预计**: 4-6 小时

### P3（持续）
7. ⏳ **改进自动化验证工具**
   - 更新 `verify_ffi_commands.py`
   - 集成到 CI/CD 流程
   - **预计**: 持续进行

---

## 实施步骤

### 步骤 1: 修复发送消息命令（P0）

**文件**: `apps/ios/Shared/Model/AppAPITypes.swift`

**1.1 更新枚举定义**（约第 20-30 行）:
```swift
// 当前
case apiSendMessages(
    type: ChatType, 
    id: Int64, 
    scope: GroupChatScope?, 
    sendAsGroup: Bool, 
    live: Bool, 
    ttl: Int?, 
    composedMessages: ComposedMessages
)

// 修改为
case apiSendMessages(
    type: ChatType, 
    id: Int64, 
    scope: GroupChatScope?, 
    sendAsGroup: Bool, 
    live: Bool, 
    ttl: Int?,
    sign: Bool,              // ✅ 新增
    burnAfterRead: Int?,     // ✅ 新增
    composedMessages: ComposedMessages
)
```

**1.2 更新命令字符串生成**（第 264-268 行）:
```swift
// 当前
case let .apiSendMessages(type, id, scope, sendAsGroup, live, ttl, composedMessages):
    let msgs = encodeJSON(composedMessages)
    let ttlStr = ttl != nil ? "\(ttl ?? 0)" : "default"
    let asGroup = sendAsGroup ? "(as_group=on)" : ""
    return "/_send \(ref(type, id, scope: scope))\(asGroup) live=\(onOff(live)) ttl=\(ttlStr) json \(msgs)"

// 修改为
case let .apiSendMessages(type, id, scope, sendAsGroup, live, ttl, sign, burnAfterRead, composedMessages):
    let msgs = encodeJSON(composedMessages)
    let ttlStr = ttl != nil ? "\(ttl ?? 0)" : "default"
    let asGroup = sendAsGroup ? "(as_group=on)" : ""
    let signStr = " sign=\(onOff(sign))"
    let burnStr = burnAfterRead != nil ? " burnAfterRead=\(burnAfterRead!)" : ""
    return "/_send \(ref(type, id, scope: scope))\(asGroup) live=\(onOff(live)) ttl=\(ttlStr)\(signStr)\(burnStr) json \(msgs)"
```

**1.3 更新所有调用点**:
```bash
# 搜索所有调用
grep -rn "\.apiSendMessages" apps/ios/

# 典型调用点更新
// 当前
try await chatSendCmd(.apiSendMessages(
    type: chatType,
    id: chatId,
    scope: scope,
    sendAsGroup: false,
    live: false,
    ttl: nil,
    composedMessages: messages
))

// 修改为
try await chatSendCmd(.apiSendMessages(
    type: chatType,
    id: chatId,
    scope: scope,
    sendAsGroup: false,
    live: false,
    ttl: nil,
    sign: true,              // ✅ 新增
    burnAfterRead: nil,      // ✅ 新增
    composedMessages: messages
))
```

**1.4 编写单元测试**:
```swift
func testSendMessageCommand() {
    let cmd = ChatCommand.apiSendMessages(
        type: .direct,
        id: 123,
        scope: nil,
        sendAsGroup: false,
        live: false,
        ttl: nil,
        sign: true,
        burnAfterRead: nil,
        composedMessages: ComposedMessages(...)
    )
    XCTAssertEqual(cmd.cmdString, "/_send direct 123 live=off ttl=default sign=on json {...}")
}
```

**1.5 测试验证**:
- 在模拟器上运行应用
- 发送测试消息
- 验证消息成功发送和接收

### 步骤 2: 验证 POPOPX 特有命令（P1）

**2.1 检查 Haskell 解析器**:
```bash
grep -n "compute\|binthere" src/Popopx/Chat/Library/Commands.hs
```

**2.2 如果缺失，添加解析器**:

**文件**: `src/Popopx/Chat/Library/Commands.hs`

在 `chatCommandP` 函数中添加:
```haskell
-- 计算购买命令
, "/_get compute balance " *> (APIGetComputeBalance <$> A.decimal)
, "/_record compute purchase " *> (APIRecordComputePurchase <$> A.decimal <* A.space <*> jsonP)
, "/_get compute purchases " *> (APIGetComputePurchases <$> A.decimal)

-- BinThere 机器人命令
, "/_get binthere bots " *> (APIGetBinThereBots <$> A.decimal <*> optional (A.space *> strP))
, "/_insert binthere bot " *> do
    userId <- A.decimal
    address <- " address=" *> strP
    name <- optional (" name=" *> strP)
    botType <- " type=" *> strP <|> pure "binthere"
    pure $ APIInsertBinThereBot userId address name botType
, "/_report binthere bot use " *> (APIReportBinThereBotUse <$> A.decimal <* A.space <*> A.decimal)
, "/_sync bot directory " *> (APISyncBotDirectory <$> A.decimal <* A.space <*> jsonP)
```

**2.3 验证 ChatCommand 定义**:

**文件**: `src/Popopx/Chat/Controller.hs`

确保有对应的构造函数:
```haskell
data ChatCommand
  = -- ... 现有命令
  | APIGetComputeBalance UserId
  | APIRecordComputePurchase UserId ComputePurchaseFFI
  | APIGetComputePurchases UserId
  | APIGetBinThereBots UserId (Maybe String)
  | APIInsertBinThereBot UserId String (Maybe String) String
  | APIReportBinThereBotUse UserId Int64
  | APISyncBotDirectory UserId String
```

**2.4 测试命令执行**:
- 在 iOS 端调用这些命令
- 验证 Haskell 端正确解析和执行

### 步骤 3: 验证其他命令（P2）

**3.1 启动聊天命令**:
```bash
# 检查所有调用点
grep -rn "\.startChat" apps/ios/

# 确认参数完整性
# 如需要，添加 serviceRequests 参数
```

**3.2 获取聊天列表命令**:
```bash
# 检查 pcc 参数来源
grep -rn "pcc" apps/ios/Shared/Model/AppAPITypes.swift

# 确认是否可能为 nil
# 如需要，更新命令生成逻辑
```

---

## 风险评估

| 风险 | 等级 | 影响 | 缓解措施 |
|------|------|------|---------|
| 发送消息命令修复 | 高 | 修改枚举定义影响大量调用点 | 全局搜索确保所有调用点更新 |
| POPOPX 命令缺失 | 中 | 功能不可用 | 优先验证并添加解析器 |
| 参数顺序错误 | 中 | 命令解析失败 | 仔细对比 Haskell 解析器 |
| JSON 编码不一致 | 中 | 数据解码失败 | 使用相同的 JSON 库 |
| 可选参数处理 | 低 | 功能受限 | 提供合理的默认值 |

---

## 测试策略

### 单元测试
- 命令字符串生成测试
- JSON 编码/解码测试
- 参数验证测试

### 集成测试
- 端到端消息发送测试
- 计算购买流程测试
- BinThere 机器人流程测试

### 手动测试
- 在模拟器上测试所有关键功能
- 在真机上测试 FFI 调用
- 性能测试

---

## 监控和告警

### 日志监控
```swift
// iOS 端
logger.debug("FFI CMD: \(cmd.cmdString)")
logger.error("FFI ERROR: \(error)")

// Haskell 端
liftIO $ TIO.hPutStrLn stderr $ "[CMD] " <> decodeUtf8 s
```

### 指标监控
- 命令成功率
- 响应时间
- FFI 调用异常

### 告警规则
- 命令失败率 > 5%: 立即告警
- 响应时间 > 1s: 警告
- FFI 调用异常: 立即告警

---

## 生成的文档

1. **FFI_INTERFACE_VERIFICATION.md**: 初始验证报告
2. **FFI_COMMAND_MANUAL_COMPARISON.md**: 手动对比结果
3. **FFI_FIX_SOLUTION.md**: 详细修复方案
4. **FFI_FIX_SUMMARY.md**: 本文档（总结）
5. **scripts/verify_ffi_commands.py**: 自动化验证工具

---

## 结论

通过系统化验证 iOS App 和 Haskell Core 之间的 FFI 接口，发现：

✅ **已验证正确**:
- FFI 函数签名匹配
- 基本命令格式正确
- JSON 编码/解码一致
- 内存管理正确

❌ **严重问题**:
- 发送消息命令缺少 `sign` 和 `burnAfterRead` 参数（P0，立即修复）

⚠️ **需要验证**:
- POPOPX 特有命令的 Haskell 解析器（P1，本周）
- 启动聊天命令参数完整性（P1，本周）
- 获取聊天列表命令参数处理（P1，本周）

**建议行动**:
1. 立即修复发送消息命令（2-3 小时）
2. 本周验证并修复其他问题（6-10 小时）
3. 下周建立持续验证机制（6-9 小时）

**预期结果**:
- 消除 FFI 接口数据格式不一致问题
- 提高系统稳定性和可靠性
- 建立长期验证机制，防止未来问题

---

## 附录

### A. 相关文件路径

**iOS 端**:
- 命令定义: `apps/ios/Shared/Model/AppAPITypes.swift`
- FFI 调用: `apps/ios/POPOPXSwitch/API.swift`
- 类型定义: `apps/ios/Shared/Model/POPOPXAPI.swift`

**Haskell 端**:
- 命令解析: `src/Popopx/Chat/Library/Commands.hs`
- FFI 导出: `src/Popopx/Chat/Mobile.hs`
- 类型定义: `src/Popopx/Chat/Controller.hs`

### B. 有用的命令

**搜索命令定义**:
```bash
# iOS 端
grep -rn "case.*apiSendMessages" apps/ios/

# Haskell 端
grep -rn "APISendMessages" src/
```

**验证命令格式**:
```bash
# 运行自动化验证
python3 scripts/verify_ffi_commands.py
```

**编译验证**:
```bash
# iOS
cd apps/ios
xcodebuild -project POPOPX.xcodeproj -scheme "POPOPX (iOS)" build

# Haskell
cabal build --flag client_library --flag swift
```

### C. 参考资料

- [FFI 接口规范](apps/ios/spec/api.md)
- [架构文档](apps/ios/spec/architecture.md)
- [Haskell FFI 指南](https://www.haskell.org/ghc/doc/users_guide/ffi.html)
- [Swift 与 C 互操作](https://developer.apple.com/documentation/swift/imported-c-and-objective-c-c-apis)
