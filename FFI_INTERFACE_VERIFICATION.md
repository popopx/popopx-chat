# FFI 接口验证报告

## 验证日期
2026-10-30

## 验证范围
iOS App 与 Haskell Core 之间的 FFI 接口数据格式一致性

## 关键接口

### 1. 初始化接口
- `chat_migrate_init_key(path, key, keepKey, confirm, backgroundMode, ctrl)`
- **状态**: ✅ 参数类型匹配
- **注意**: keepKey 和 backgroundMode 是 CInt (0/1), confirm 是字符串枚举

### 2. 命令发送接口
- `chat_send_cmd_retry(ctrl, cmd, retryNum)`
- **状态**: ⚠️ 需要验证命令字符串格式
- **关键**: iOS 的 `cmdString` 必须与 Haskell 的 `chatCommandP` 解析器完全匹配

### 3. 消息接收接口
- `chat_recv_msg_wait(ctrl, wait)`
- **状态**: ✅ 参数类型匹配
- **注意**: wait 是微秒 (CInt)

### 4. 辅助接口
- `chat_parse_markdown(str)` → JSON
- `chat_parse_server(str)` → JSON
- `chat_parse_uri(str, safe)` → JSON
- `chat_password_hash(pwd, salt)` → string
- `chat_valid_name(name)` → string
- `chat_json_length(str)` → int

## 已发现的问题

### 问题 1: 命令字符串格式验证
**严重程度**: 高
**描述**: iOS 生成的命令字符串可能与 Haskell 解析器期望的格式不完全匹配
**影响**: 命令解析失败，功能不可用
**解决方案**: 
1. 创建命令格式对照表
2. 编写单元测试验证每个命令的往返解析
3. 在开发环境添加命令日志对比

### 问题 2: JSON 编码/解码一致性
**严重程度**: 中
**描述**: Haskell 的 `sumTypeJSON` 与 iOS 的 OWSF 预处理可能存在边界情况
**影响**: 某些响应类型解码失败
**解决方案**:
1. 收集所有 ChatResponse 类型
2. 为每个类型创建测试用例
3. 验证 OWSF 预处理的正确性

### 问题 3: 数据类型对齐
**严重程度**: 中
**描述**: Int64/Int、Maybe/Optional 等类型可能不匹配
**影响**: 解码错误或数据丢失
**解决方案**:
1. 审查所有 FFI 相关的数据类型定义
2. 确保 Swift 类型与 Haskell 类型完全对应
3. 特别注意可选字段的处理

## 验证步骤

### 步骤 1: 命令格式验证
```bash
# 在 iOS 端添加日志
logger.debug("CMD: \(cmd.cmdString)")

# 在 Haskell 端添加日志
liftIO $ TIO.hPutStrLn stderr $ "[CMD] " <> decodeUtf8 s
```

### 步骤 2: 响应格式验证
```bash
# 在 Haskell 端记录响应 JSON
liftIO $ TIO.hPutStrLn stderr $ "[RESP] " <> LB.unpack (J.encode resp)

# 在 iOS 端记录原始响应
logger.debug("RESP: \(String(data: d, encoding: .utf8) ?? "nil")")
```

### 步骤 3: 端到端测试
1. 启动 iOS 应用
2. 执行关键操作（创建用户、发送消息、接收消息）
3. 对比日志中的命令和响应格式
4. 识别不匹配的地方

## 建议的修复优先级

1. **P0 (立即)**: 验证核心命令格式
   - `/_create user`
   - `/_start`
   - `/_get chats`
   - `/_send`
   - `/_get chat`

2. **P1 (本周)**: 验证所有命令格式
   - 列出所有 ChatCommand 案例
   - 逐个验证格式

3. **P2 (下周)**: 验证响应解码
   - 列出所有 ChatResponse 类型
   - 创建测试用例
   - 验证 OWSF 预处理

4. **P3 (持续)**: 添加自动化测试
   - 单元测试覆盖所有命令
   - 集成测试验证端到端流程

## 工具建议

### 命令格式对比工具
创建一个脚本自动对比 iOS 和 Haskell 的命令格式：
```python
# 提取 iOS cmdString
# 提取 Haskell chatCommandP
# 生成对比报告
```

### JSON 格式验证工具
创建一个测试套件验证 JSON 往返：
```swift
// 1. iOS 生成命令 JSON
// 2. Haskell 解析并响应
// 3. iOS 解码响应
// 4. 验证数据一致性
```

## 结论

FFI 接口的基本框架是正确的，但需要系统化验证命令字符串格式和 JSON 编码/解码的一致性。建议立即开始 P0 优先级的验证工作，并建立持续的自动化测试机制。
