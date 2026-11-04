# FFI 接口关键命令格式对照表

## 说明
本文档手动对比 iOS Swift 和 Haskell 之间的关键 FFI 命令格式，确保数据解析一致性。

## 命令格式约定
- **Swift**: 使用字符串插值生成命令，如 `"/_get chats \(userId)"`
- **Haskell**: 使用 attoparsec 解析器，如 `"/_get chats" *> (APIGetChats <$> A.decimal)`
- **参数**: 使用 `{VAR}` 表示变量部分

---

## 1. 用户管理命令

### 1.1 显示活跃用户
| 端 | 格式 |
|---|---|
| **Swift** | `/u` |
| **Haskell** | `("/user" <|> "/u") $> ShowActiveUser` |
| **状态** | ✅ 匹配 |

### 1.2 创建活跃用户
| 端 | 格式 |
|---|---|
| **Swift** | `/_create user {JSON}` |
| **Haskell** | `"/_create user " *> (CreateActiveUser <$> jsonP)` |
| **状态** | ✅ 匹配 |
| **注意** | JSON 必须是 `NewUser` 类型的有效编码 |

### 1.3 设置活跃用户
| 端 | 格式 |
|---|---|
| **Swift** | `/_user {userId} {JSON?}` |
| **Haskell** | `"/_user " *> (APISetActiveUser <$> A.decimal <*> optional (A.space *> jsonP))` |
| **状态** | ✅ 匹配 |

### 1.4 列出用户
| 端 | 格式 |
|---|---|
| **Swift** | `/users` |
| **Haskell** | `"/users" $> ListUsers` |
| **状态** | ✅ 匹配 |

---

## 2. 聊天生命周期命令

### 2.1 启动聊天
| 端 | 格式 |
|---|---|
| **Swift** | `/_start main={on|off} snd_files={on|off}` |
| **Haskell** | `"/_start " *> do { mainApp <- "main=" *> onOffP; enableSndFiles <- " snd_files=" *> onOffP ... }` |
| **状态** | ⚠️ 需验证 |
| **问题** | Swift 是否包含所有必需参数？ |

### 2.2 检查聊天运行状态
| 端 | 格式 |
|---|---|
| **Swift** | `/_check running` |
| **Haskell** | `"/_check running" $> CheckChatRunning` |
| **状态** | ✅ 匹配 |

### 2.3 停止聊天
| 端 | 格式 |
|---|---|
| **Swift** | `/_stop` |
| **Haskell** | `"/_stop" $> APIStopChat` |
| **状态** | ✅ 匹配 |

### 2.4 激活聊天
| 端 | 格式 |
|---|---|
| **Swift** | `/_app activate restore={on|off}` |
| **Haskell** | `"/_app activate restore=" *> (APIActivateChat <$> onOffP)` |
| **状态** | ✅ 匹配 |

### 2.5 暂停聊天
| 端 | 格式 |
|---|---|
| **Swift** | `/_app suspend {microseconds}` |
| **Haskell** | `"/_app suspend " *> (APISuspendChat <$> A.decimal)` |
| **状态** | ✅ 匹配 |

---

## 3. 聊天列表和获取命令

### 3.1 获取聊天列表
| 端 | 格式 |
|---|---|
| **Swift** | `/_get chats {userId} pcc={on|off}` |
| **Haskell** | `"/_get chats" *> (APIGetChats <$> A.decimal <*> (" pcc=on" $> True <|> " pcc=off" $> False <|> pure False) <*> ...)` |
| **状态** | ⚠️ 需验证 |
| **问题** | `pcc` 参数在 Swift 中是否总是包含？Haskell 允许省略 |

### 3.2 获取单个聊天
| 端 | 格式 |
|---|---|
| **Swift** | `/_get chat {chatRef} {scope?} {tag?} {pagination} search={text}` |
| **Haskell** | `"/_get chat " *> (APIGetChat <$> chatRefP <*> optional (" content=" *> strP) <* A.space <*> chatPaginationP <*> optional (" search=" *> textP))` |
| **状态** | ⚠️ 需验证 |
| **问题** | 参数顺序和可选参数处理是否一致？ |

### 3.3 获取聊天标签
| 端 | 格式 |
|---|---|
| **Swift** | `/_get tags {userId}` |
| **Haskell** | `"/_get tags " *> (APIGetChatTags <$> A.decimal)` |
| **状态** | ✅ 匹配 |

---

## 4. 消息发送命令

### 4.1 发送消息
| 端 | 格式 |
|---|---|
| **Swift** | `/_send {sendRef} live={on|off} ttl={seconds|default} sign={on|off} json {JSON}` |
| **Haskell** | `"/_send " *> (APISendMessages <$> sendRefP <*> liveMessageP <*> sendMessageTTLP <*> signMessagesP <*> burnAfterReadP <*> (" json " *> jsonP <|> " text " *> composedMessagesTextP))` |
| **状态** | ❌ 不匹配 |
| **问题** | Swift 缺少 `burnAfterRead` 参数！Haskell 期望在 `sign` 之后有 `burnAfterRead` |

### 4.2 更新聊天项
| 端 | 格式 |
|---|---|
| **Swift** | `/_update item {chatRef} {itemId} live={on|off} json {JSON}` |
| **Haskell** | `"/_update item " *> (APIUpdateChatItem <$> chatRefP <* A.space <*> A.decimal <*> liveMessageP <*> (" json" *> jsonP <|> " text " *> updatedMessagesTextP))` |
| **状态** | ✅ 匹配 |

### 4.3 删除聊天项
| 端 | 格式 |
|---|---|
| **Swift** | `/_delete item {chatRef} {itemIds} {mode}` |
| **Haskell** | `"/_delete item " *> (APIDeleteChatItem <$> chatRefP <*> _strP <*> _strP)` |
| **状态** | ⚠️ 需验证 |
| **问题** | `itemIds` 格式是否为逗号分隔？`mode` 是否为有效枚举？ |

---

## 5. 服务器操作员命令

### 5.1 获取服务器操作员
| 端 | 格式 |
|---|---|
| **Swift** | `/_operators` |
| **Haskell** | `"/_operators" $> APIGetServerOperators` |
| **状态** | ✅ 匹配 |

### 5.2 设置服务器操作员
| 端 | 格式 |
|---|---|
| **Swift** | `/_operators {JSON}` |
| **Haskell** | `"/_operators " *> (APISetServerOperators <$> jsonP)` |
| **状态** | ✅ 匹配 |
| **注意** | JSON 必须是 `[ServerOperator]` 数组 |

### 5.3 获取用户服务器
| 端 | 格式 |
|---|---|
| **Swift** | `/_get user servers {userId}` |
| **Haskell** | `"/_get user servers " *> (APIGetUserServers <$> A.decimal)` |
| **状态** | ✅ 匹配 |

### 5.4 设置用户服务器
| 端 | 格式 |
|---|---|
| **Swift** | `/_set user servers {userId} {JSON}` |
| **Haskell** | `"/_set user servers " *> (APISetUserServers <$> A.decimal <* A.space <*> jsonP)` |
| **状态** | ✅ 匹配 |

---

## 6. 计算购买命令（POPOPX 特有）

### 6.1 获取计算余额
| 端 | 格式 |
|---|---|
| **Swift** | `/_get compute balance {userId}` |
| **Haskell** | 需验证是否存在此解析器 |
| **状态** | ⚠️ 需验证 |
| **问题** | Haskell 端是否有对应的解析器？ |

### 6.2 记录计算购买
| 端 | 格式 |
|---|---|
| **Swift** | `/_record compute purchase {userId} {JSON}` |
| **Haskell** | 需验证是否存在此解析器 |
| **状态** | ⚠️ 需验证 |

---

## 7. BinThere 机器人命令（POPOPX 特有）

### 7.1 获取 BinThere 机器人
| 端 | 格式 |
|---|---|
| **Swift** | `/_get binthere bots {userId} {botType?}` |
| **Haskell** | 需验证是否存在此解析器 |
| **状态** | ⚠️ 需验证 |

### 7.2 插入 BinThere 机器人
| 端 | 格式 |
|---|---|
| **Swift** | `/_insert binthere bot {userId} address={address} name={name?} type={botType}` |
| **Haskell** | 需验证是否存在此解析器 |
| **状态** | ⚠️ 需验证 |

---

## 关键问题总结

### ❌ 严重问题（必须修复）

1. **发送消息命令缺少 burnAfterRead 参数**
   - **位置**: `AppAPITypes.swift` 第 264-266 行
   - **Swift**: `/_send {sendRef} live={on|off} ttl={seconds} sign={on|off} json {JSON}`
   - **Haskell**: 期望 `/_send {sendRef} live={on|off} ttl={seconds} sign={on|off} burnAfterRead={seconds} json {JSON}`
   - **影响**: 消息发送失败
   - **修复**: 在 Swift 的 `apiSendMessages` 命令中添加 `burnAfterRead` 参数

### ⚠️ 需要验证的问题

2. **启动聊天命令参数完整性**
   - **位置**: `AppAPITypes.swift` 第 243 行
   - **问题**: Swift 是否总是包含 `main` 和 `snd_files` 参数？
   - **验证**: 检查所有调用点

3. **获取聊天列表的 pcc 参数**
   - **位置**: `AppAPITypes.swift` 第 253 行
   - **问题**: Swift 是否总是包含 `pcc` 参数？Haskell 允许省略
   - **验证**: 检查命令生成逻辑

4. **POPOPX 特有命令的 Haskell 解析器**
   - **问题**: 计算购买和 BinThere 机器人命令在 Haskell 端是否有对应的解析器？
   - **验证**: 搜索 `Commands.hs` 中的相关解析器

---

## 建议的验证步骤

### 立即执行（P0）

1. **修复发送消息命令**
   ```swift
   // 在 AppAPITypes.swift 中
   case let .apiSendMessages(type, id, scope, sendAsGroup, live, ttl, sign, burnAfterRead, messages):
       let burnStr = burnAfterRead != nil ? " burnAfterRead=\(burnAfterRead!)" : ""
       return "/_send \(ref(type, id, scope: scope, sendAsGroup: sendAsGroup)) live=\(onOff(live)) ttl=\(ttl ?? 0) sign=\(onOff(sign))\(burnStr) json \(encodeJSON(messages))"
   ```

2. **验证启动聊天命令**
   - 搜索所有 `.startChat` 调用
   - 确认参数完整性

### 本周执行（P1）

3. **验证 POPOPX 特有命令**
   - 在 `Commands.hs` 中搜索 `compute`、`binthere` 相关解析器
   - 如果不存在，添加对应的解析器

4. **创建端到端测试**
   - 为每个关键命令创建测试用例
   - 验证命令字符串在两端的一致性

### 下周执行（P2）

5. **添加命令日志**
   - 在 iOS 端记录所有发送的命令
   - 在 Haskell 端记录所有解析的命令
   - 对比日志发现不一致

6. **自动化验证**
   - 改进 `verify_ffi_commands.py` 脚本
   - 基于实际命令字符串而非枚举名称进行匹配

---

## JSON 编码/解码注意事项

### 1. OWSF 格式
Haskell 使用 `_owsf` 标签表示和类型：
```json
{
  "_owsf": true,
  "activeUser": {
    "user": {...}
  }
}
```

iOS 有预处理步骤转换为标准格式：
```json
{
  "activeUser": {
    "user": {...}
  }
}
```

**验证**: 确保 `preprocessOWSF` 正确处理所有嵌套情况

### 2. 枚举编码
Haskell 枚举使用 `enumJSON`：
```haskell
$(JQ.deriveJSON (enumJSON $ dropPrefix "RTS") ''RelayTestStep)
```

iOS 使用 `RawRepresentable`：
```swift
enum RelayTestStep: String, Codable {
    case rtsCreateWorker
    case rtsConnect
}
```

**验证**: 确保枚举值名称完全匹配（去除前缀后）

### 3. 可选字段
Haskell: `Maybe a` → JSON: 字段可能不存在或为 `null`
iOS: `Optional<T>` → JSON: 字段可能不存在或为 `null`

**验证**: 确保两端对 `null` 和缺失字段的处理一致

---

## 结论

发现 **1 个严重问题**（发送消息命令缺少参数）和 **4 个需要验证的问题**。

**立即行动**:
1. 修复发送消息命令的 `burnAfterRead` 参数
2. 验证 POPOPX 特有命令在 Haskell 端的解析器

**后续行动**:
1. 创建端到端测试
2. 添加命令日志对比
3. 改进自动化验证工具
