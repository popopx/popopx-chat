# FFI 接口问题修复方案

## 执行摘要

通过对比 iOS Swift 和 Haskell Core 的 FFI 接口，发现 **1 个严重问题** 和 **多个需要验证的问题**。

**严重问题**: 发送消息命令缺少 `sign` 和 `burnAfterRead` 参数，导致消息发送必然失败。

---

## 问题 1: 发送消息命令参数不匹配 ❌ 严重

### 问题描述

**Haskell 端期望格式** (`Commands.hs:6392`):
```haskell
"/_send " *> (APISendMessages 
  <$> sendRefP           -- 聊天引用
  <*> liveMessageP       -- live=on|off
  <*> sendMessageTTLP    -- ttl={seconds|default}
  <*> signMessagesP      -- sign=on|off ❌ 缺失
  <*> burnAfterReadP     -- burnAfterRead={seconds} ❌ 缺失
  <*> (" json " *> jsonP <|> " text " *> composedMessagesTextP))
```

**iOS 端实际格式** (`AppAPITypes.swift:268`):
```swift
"/_send \(ref(type, id, scope: scope))\(asGroup) live=\(onOff(live)) ttl=\(ttlStr) json \(msgs)"
```

### 影响

- **严重程度**: P0 - 阻塞性问题
- **影响范围**: 所有消息发送功能
- **症状**: Haskell 解析命令失败，返回错误

### 修复方案

#### 步骤 1: 更新 Swift 枚举定义

**文件**: `apps/ios/Shared/Model/AppAPITypes.swift`

**当前定义** (约第 20-30 行):
```swift
enum ChatCommand: ChatCmdProtocol, @unchecked Sendable {
    // ...
    case apiSendMessages(
        type: ChatType, 
        id: Int64, 
        scope: GroupChatScope?, 
        sendAsGroup: Bool, 
        live: Bool, 
        ttl: Int?, 
        composedMessages: ComposedMessages
    )
    // ...
}
```

**修改为**:
```swift
enum ChatCommand: ChatCmdProtocol, @unchecked Sendable {
    // ...
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
    // ...
}
```

#### 步骤 2: 更新命令字符串生成

**文件**: `apps/ios/Shared/Model/AppAPITypes.swift`

**当前实现** (第 264-268 行):
```swift
case let .apiSendMessages(type, id, scope, sendAsGroup, live, ttl, composedMessages):
    let msgs = encodeJSON(composedMessages)
    let ttlStr = ttl != nil ? "\(ttl ?? 0)" : "default"
    let asGroup = sendAsGroup ? "(as_group=on)" : ""
    return "/_send \(ref(type, id, scope: scope))\(asGroup) live=\(onOff(live)) ttl=\(ttlStr) json \(msgs)"
```

**修改为**:
```swift
case let .apiSendMessages(type, id, scope, sendAsGroup, live, ttl, sign, burnAfterRead, composedMessages):
    let msgs = encodeJSON(composedMessages)
    let ttlStr = ttl != nil ? "\(ttl ?? 0)" : "default"
    let asGroup = sendAsGroup ? "(as_group=on)" : ""
    let signStr = " sign=\(onOff(sign))"
    let burnStr = burnAfterRead != nil ? " burnAfterRead=\(burnAfterRead!)" : ""
    return "/_send \(ref(type, id, scope: scope))\(asGroup) live=\(onOff(live)) ttl=\(ttlStr)\(signStr)\(burnStr) json \(msgs)"
```

#### 步骤 3: 更新所有调用点

**搜索所有调用 `.apiSendMessages` 的地方**:
```bash
grep -rn "apiSendMessages" apps/ios/
```

**典型调用点** (可能在 `POPOPXAPI.swift` 或消息发送相关代码中):
```swift
// 当前调用
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
    sign: true,              // ✅ 新增 - 默认签名
    burnAfterRead: nil,      // ✅ 新增 - 默认不焚毁
    composedMessages: messages
))
```

#### 步骤 4: 验证 Haskell 解析器

**确认 Haskell 端的参数解析顺序**:
```haskell
-- Commands.hs:6392
"/_send " *> (APISendMessages 
  <$> sendRefP           -- 1. 聊天引用
  <*> liveMessageP       -- 2. live=on|off
  <*> sendMessageTTLP    -- 3. ttl={seconds|default}
  <*> signMessagesP      -- 4. sign=on|off
  <*> burnAfterReadP     -- 5. burnAfterRead={seconds}
  <*> (" json " *> jsonP <|> " text " *> composedMessagesTextP))  -- 6. json/text + 内容
```

**验证 Swift 生成的命令格式**:
```
/_send {chatRef} live={on|off} ttl={seconds|default} sign={on|off} burnAfterRead={seconds} json {JSON}
```

### 测试验证

#### 测试用例 1: 基本消息发送
```swift
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
```

#### 测试用例 2: 带 TTL 的消息
```swift
let cmd = ChatCommand.apiSendMessages(
    type: .direct,
    id: 123,
    scope: nil,
    sendAsGroup: false,
    live: false,
    ttl: 3600,
    sign: true,
    burnAfterRead: nil,
    composedMessages: ComposedMessages(...)
)
XCTAssertEqual(cmd.cmdString, "/_send direct 123 live=off ttl=3600 sign=on json {...}")
```

#### 测试用例 3: 焚毁后读消息
```swift
let cmd = ChatCommand.apiSendMessages(
    type: .direct,
    id: 123,
    scope: nil,
    sendAsGroup: false,
    live: false,
    ttl: nil,
    sign: true,
    burnAfterRead: 60,
    composedMessages: ComposedMessages(...)
)
XCTAssertEqual(cmd.cmdString, "/_send direct 123 live=off ttl=default sign=on burnAfterRead=60 json {...}")
```

#### 测试用例 4: 群组消息
```swift
let cmd = ChatCommand.apiSendMessages(
    type: .group,
    id: 456,
    scope: .member(groupId: 789),
    sendAsGroup: true,
    live: true,
    ttl: nil,
    sign: false,
    burnAfterRead: nil,
    composedMessages: ComposedMessages(...)
)
XCTAssertEqual(cmd.cmdString, "/_send group 456 (as_group=on) live=on ttl=default sign=off json {...}")
```

---

## 问题 2: POPOPX 特有命令的 Haskell 解析器缺失 ⚠️ 需验证

### 问题描述

iOS 端定义了以下 POPOPX 特有命令，但需要验证 Haskell 端是否有对应的解析器：

1. **计算购买相关**:
   - `/_get compute balance {userId}`
   - `/_record compute purchase {userId} {JSON}`
   - `/_get compute purchases {userId}`

2. **BinThere 机器人相关**:
   - `/_get binthere bots {userId} {botType?}`
   - `/_insert binthere bot {userId} address={address} name={name?} type={botType}`
   - `/_report binthere bot use {userId} {botId}`
   - `/_sync bot directory {userId} {JSON}`

### 验证步骤

**搜索 Haskell 解析器**:
```bash
grep -n "compute balance\|compute purchase\|binthere bot" src/Popopx/Chat/Library/Commands.hs
```

**如果不存在，需要添加**:

#### 添加计算购买命令解析器

**文件**: `src/Popopx/Chat/Library/Commands.hs`

**位置**: 在 `chatCommandP` 函数中添加

```haskell
-- 获取计算余额
, "/_get compute balance " *> (APIGetComputeBalance <$> A.decimal)

-- 记录计算购买
, "/_record compute purchase " *> (APIRecordComputePurchase <$> A.decimal <* A.space <*> jsonP)

-- 获取计算购买历史
, "/_get compute purchases " *> (APIGetComputePurchases <$> A.decimal)
```

#### 添加 BinThere 机器人命令解析器

```haskell
-- 获取 BinThere 机器人列表
, "/_get binthere bots " *> (APIGetBinThereBots <$> A.decimal <*> optional (A.space *> strP))

-- 插入 BinThere 机器人
, "/_insert binthere bot " *> do
    userId <- A.decimal
    address <- " address=" *> strP
    name <- optional (" name=" *> strP)
    botType <- " type=" *> strP <|> pure "binthere"
    pure $ APIInsertBinThereBot userId address name botType

-- 报告 BinThere 机器人使用
, "/_report binthere bot use " *> (APIReportBinThereBotUse <$> A.decimal <* A.space <*> A.decimal)

-- 同步机器人目录
, "/_sync bot directory " *> (APISyncBotDirectory <$> A.decimal <* A.space <*> jsonP)
```

### 验证 ChatCommand 定义

**确保 Haskell 端有对应的 ChatCommand 构造函数**:

**文件**: `src/Popopx/Chat/Controller.hs`

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
  -- ...
```

---

## 问题 3: 启动聊天命令参数验证 ⚠️ 需验证

### 问题描述

**Haskell 端** (`Commands.hs:6342-6347`):
```haskell
"/_start " *> do
  mainApp <- "main=" *> onOffP
  enableSndFiles <- " snd_files=" *> onOffP <|> pure mainApp
  serviceRequests <- " service_requests=" *> onOffP <|> pure False
  pure StartChat {mainApp, enableSndFiles, serviceRequests}
```

**iOS 端** (`AppAPITypes.swift:243`):
```swift
case let .startChat(mainApp, enableSndFiles):
    return "/_start main=\(onOff(mainApp)) snd_files=\(onOff(enableSndFiles))"
```

### 潜在问题

1. **缺少 `service_requests` 参数**: Haskell 支持但 iOS 未发送
2. **参数顺序**: 必须确保 `main` 在 `snd_files` 之前

### 验证步骤

**检查所有调用点**:
```bash
grep -rn "\.startChat" apps/ios/
```

**确认参数完整性**:
- 是否所有调用都包含 `mainApp` 和 `enableSndFiles`？
- 是否需要添加 `serviceRequests` 参数？

### 修复方案（如需要）

**更新 Swift 枚举**:
```swift
case startChat(mainApp: Bool, enableSndFiles: Bool, serviceRequests: Bool = false)
```

**更新命令字符串**:
```swift
case let .startChat(mainApp, enableSndFiles, serviceRequests):
    return "/_start main=\(onOff(mainApp)) snd_files=\(onOff(enableSndFiles)) service_requests=\(onOff(serviceRequests))"
```

---

## 问题 4: 获取聊天列表的 pcc 参数 ⚠️ 需验证

### 问题描述

**Haskell 端** (`Commands.hs:6381-6387`):
```haskell
"/_get chats"
  *> ( APIGetChats
        <$> A.decimal
        <*> (" pcc=on" $> True <|> " pcc=off" $> False <|> pure False)  -- 可选参数
        <*> optional (A.space *> paginationByTimeP)
        <*> (A.space *> jsonP <|> pure clqNoFilters)
     )
```

**iOS 端** (`AppAPITypes.swift:253`):
```swift
case let .apiGetChats(userId):
    return "/_get chats \(userId) pcc=\(onOff(pcc))"
```

### 潜在问题

1. **iOS 总是发送 `pcc` 参数**: 但 Haskell 允许省略
2. **参数顺序**: 必须确保 `userId` 在 `pcc` 之前

### 验证步骤

**检查 `pcc` 的来源**:
```bash
grep -rn "pcc" apps/ios/Shared/Model/AppAPITypes.swift
```

**确认是否总是有值**:
- `pcc` 是从哪里获取的？
- 是否可能为 `nil`？

### 修复方案（如需要）

**如果 `pcc` 可能为 `nil`**:
```swift
case let .apiGetChats(userId, pcc):
    let pccStr = pcc != nil ? " pcc=\(onOff(pcc!))" : ""
    return "/_get chats \(userId)\(pccStr)"
```

---

## 实施计划

### 阶段 1: 修复严重问题（P0，立即执行）

**任务 1.1**: 修复发送消息命令
- [ ] 更新 `ChatCommand.apiSendMessages` 枚举定义
- [ ] 更新命令字符串生成逻辑
- [ ] 更新所有调用点
- [ ] 编写单元测试
- [ ] 在模拟器上测试消息发送

**预计时间**: 2-3 小时

### 阶段 2: 验证 POPOPX 特有命令（P1，本周执行）

**任务 2.1**: 验证计算购买命令
- [ ] 搜索 Haskell 解析器
- [ ] 如果缺失，添加解析器
- [ ] 验证 ChatCommand 定义
- [ ] 测试命令执行

**任务 2.2**: 验证 BinThere 机器人命令
- [ ] 搜索 Haskell 解析器
- [ ] 如果缺失，添加解析器
- [ ] 验证 ChatCommand 定义
- [ ] 测试命令执行

**预计时间**: 4-6 小时

### 阶段 3: 验证其他命令（P2，下周执行）

**任务 3.1**: 验证启动聊天命令
- [ ] 检查所有调用点
- [ ] 确认参数完整性
- [ ] 如需要，添加 `serviceRequests` 参数

**任务 3.2**: 验证获取聊天列表命令
- [ ] 检查 `pcc` 参数的来源
- [ ] 确认是否可能为 `nil`
- [ ] 如需要，更新命令生成逻辑

**预计时间**: 2-3 小时

### 阶段 4: 建立持续验证机制（P3，持续执行）

**任务 4.1**: 添加命令日志
- [ ] 在 iOS 端记录所有发送的命令
- [ ] 在 Haskell 端记录所有解析的命令
- [ ] 创建日志对比工具

**任务 4.2**: 改进自动化验证
- [ ] 更新 `verify_ffi_commands.py` 脚本
- [ ] 基于实际命令字符串进行匹配
- [ ] 集成到 CI/CD 流程

**任务 4.3**: 创建端到端测试套件
- [ ] 为每个关键命令创建测试用例
- [ ] 验证命令在两端的一致性
- [ ] 定期运行测试

**预计时间**: 持续进行

---

## 风险评估

### 高风险

1. **发送消息命令修复**:
   - **风险**: 修改枚举定义可能影响大量调用点
   - **缓解**: 使用全局搜索确保所有调用点都更新
   - **回滚**: 保留旧版本代码，必要时回滚

2. **POPOPX 特有命令缺失**:
   - **风险**: 如果 Haskell 端没有解析器，这些功能完全不可用
   - **缓解**: 优先验证并添加缺失的解析器
   - **回滚**: 暂时禁用这些功能，直到解析器就绪

### 中风险

1. **参数顺序错误**:
   - **风险**: 命令解析失败
   - **缓解**: 仔细对比 Haskell 解析器的参数顺序
   - **回滚**: 调整参数顺序

2. **JSON 编码不一致**:
   - **风险**: 数据解码失败
   - **缓解**: 使用相同的 JSON 库，验证编码格式
   - **回滚**: 调整 JSON 编码逻辑

### 低风险

1. **可选参数处理**:
   - **风险**: 功能受限但不崩溃
   - **缓解**: 提供合理的默认值
   - **回滚**: 无需回滚

---

## 测试策略

### 单元测试

1. **命令字符串生成测试**:
   ```swift
   func testSendMessageCommand() {
       let cmd = ChatCommand.apiSendMessages(...)
       XCTAssertEqual(cmd.cmdString, "/_send ...")
   }
   ```

2. **JSON 编码/解码测试**:
   ```swift
   func testComputePurchaseJSON() {
       let purchase = ComputePurchaseFFI(...)
       let json = encodeJSON(purchase)
       let decoded = try jsonDecoder.decode(ComputePurchaseFFI.self, from: json)
       XCTAssertEqual(purchase, decoded)
   }
   ```

### 集成测试

1. **端到端消息发送测试**:
   - 创建用户
   - 发送消息
   - 验证消息到达

2. **计算购买流程测试**:
   - 获取余额
   - 记录购买
   - 验证余额更新

### 手动测试

1. **在模拟器上测试所有关键功能**:
   - 消息发送
   - 文件传输
   - 计算购买
   - BinThere 机器人

2. **在真机上测试**:
   - 验证 FFI 调用在真机上正常工作
   - 测试性能影响

---

## 监控和告警

### 日志监控

1. **命令日志**:
   ```swift
   logger.debug("FFI CMD: \(cmd.cmdString)")
   ```

2. **错误日志**:
   ```swift
   logger.error("FFI ERROR: \(error)")
   ```

### 指标监控

1. **命令成功率**:
   - 监控命令执行成功/失败比例
   - 设置告警阈值

2. **响应时间**:
   - 监控 FFI 调用耗时
   - 识别性能瓶颈

### 告警规则

1. **命令失败率 > 5%**: 立即告警
2. **响应时间 > 1s**: 警告
3. **FFI 调用异常**: 立即告警

---

## 文档更新

### 更新的文件

1. **FFI_INTERFACE_VERIFICATION.md**: 初始验证报告
2. **FFI_COMMAND_MANUAL_COMPARISON.md**: 手动对比结果
3. **FFI_FIX_SOLUTION.md**: 本文档
4. **FFI_FIX_SUMMARY.md**: 修复总结（待创建）

### 需要更新的文档

1. **API 规范**: `apps/ios/spec/api.md`
   - 更新命令格式说明
   - 添加新参数说明

2. **架构文档**: `apps/ios/spec/architecture.md`
   - 更新 FFI 接口说明
   - 添加数据流图

3. **开发者指南**: 创建 `FFI_DEVELOPER_GUIDE.md`
   - 如何添加新命令
   - 如何验证命令格式
   - 常见问题解答

---

## 结论

通过系统化验证，发现了 **1 个严重问题**（发送消息命令参数缺失）和 **多个需要验证的问题**。

**立即行动**:
1. ✅ 修复发送消息命令（P0，2-3 小时）
2. ⏳ 验证 POPOPX 特有命令（P1，4-6 小时）
3. ⏳ 验证其他命令参数（P2，2-3 小时）
4. ⏳ 建立持续验证机制（P3，持续）

**预期结果**:
- 消除 FFI 接口数据格式不一致问题
- 提高系统稳定性和可靠性
- 建立长期验证机制，防止未来问题

**风险可控**:
- 所有修复都有明确的测试验证方案
- 有回滚计划和缓解措施
- 风险等级已评估并分类
