# POPOPX vs Upstream SimpleX iOS App 代码对比报告

**生成时间：** 2026-10-29  
**本地版本：** POPOPX (fork)  
**上游版本：** simplex-chat v7.1.0.14

---

## 1. 核心架构差异

### 1.1 模块命名
| 项目 | POPOPX | Upstream SimpleX |
|------|--------|------------------|
| 主框架 | `POPOPXSwitch` | `SimpleXChat` |
| 导入语句 | `import POPOPXSwitch` | `import SimpleXChat` |
| 数据库路径 | `popopx_v1` | `simplex_v1` |
| App Group | `group.com.popopxchat.popopx` | `group.chat.simplex` |
| Bundle ID | `com.popopxchat.popopx` | `chat.simplex.app` |

### 1.2 文件结构差异
**POPOPX 独有文件：**
- `POPOPXApp.swift` (替代 `SimpleXApp.swift`)
- `POPOPXAPI.swift` (替代 `SimpleXAPI.swift`)
- `PXChatState.swift` (扩展的聊天状态管理)
- `AppState.swift` (应用状态模型)
- `LaunchCoordinator.swift` (启动协调器)
- `PXOnboardingCards.swift` (自定义 onboarding 卡片)

**Upstream 独有文件：**
- `AppDelegate.swift` (POPOPX 已合并到 POPOPXApp.swift)
- `SceneDelegate.swift` (POPOPX 使用 SwiftUI 生命周期)

---

## 2. 关键代码差异

### 2.1 ContentView.swift

**POPOPX 特性：**
```swift
// 自定义启动流程
@State private var launchComplete = false
@State private var initTimeoutReached = false

// 自定义 Alert 系统 (GlassAlertView - cyberpunk 风格)
.overlay {
    if alertManager.presentAlert {
        GlassAlertView(...)
    }
}

// 数据库状态检查增强
} else if let status = chatModel.chatDbStatus, status != .ok {
    Group {
        if hasValidDatabaseFiles() {
            proceedToOnboardingOrMain()
        } else {
            DatabaseErrorView(status: status)
        }
    }
}
```

**Upstream 标准实现：**
```swift
// 标准 iOS Alert
.alert(isPresented: $alertManager.presentAlert) { alertManager.alertView! }

// 简单的数据库状态检查
} else if chatModel.chatDbStatus == nil && AppChatState.shared.value != .stopped {
    initializationView()
}
```

### 2.2 POPOPXAPI.swift vs SimpleXAPI.swift

**POPOPX 增强：**
```swift
// 专用 FFI 队列防止线程爆炸
private let ffiQueue: DispatchQueue = {
    let q = DispatchQueue(label: "chat.popopx.ffi", qos: .userInitiated)
    q.setSpecific(key: ffiQueueKey, value: ())
    return q
}()

// 分离的接收队列 (防止阻塞发送命令)
private let ffiRecvQueue: DispatchQueue = {
    let q = DispatchQueue(label: "chat.popopx.ffi.recv", qos: .userInitiated)
    return q
}()

// 自动重试机制
func chatApiSendCmdWithRetry<R: ChatAPIResult>(
    _ cmd: ChatCommand,
    maxRetries: Int32 = 3,
    inProgress: BoxedValue<Bool>? = nil
) async -> APIResult<R>?

// Onboarding 状态修复 (2026-10-29)
if m.currentUser == nil {
    let currentStage = onboardingStageDefault.get()
    if currentStage != .onboardingComplete {
        advanceOnboarding(to: .step1_WelcomeIdentity)
    } else if !hasDatabase() {
        advanceOnboarding(to: .step1_WelcomeIdentity)
    } else {
        // 检查用户列表是否为空
        do {
            let users = try listUsers()
            if users.isEmpty {
                advanceOnboarding(to: .step1_WelcomeIdentity)
            }
        } catch {
            advanceOnboarding(to: .step1_WelcomeIdentity)
        }
    }
}
```

**Upstream 标准实现：**
```swift
// 使用全局 GCD 队列
func chatApiSendCmd<R: ChatAPIResult>(...) async -> APIResult<R> {
    let resp: APIResult<R> = bgTask
        ? withBGTask(bgDelay: bgDelay) { sendSimpleXCmd(cmd, ctrl, retryNum: retryNum) }
        : sendSimpleXCmd(cmd, ctrl, retryNum: retryNum)
    return resp
}

// 简单的 onboarding 检查
if m.currentUser == nil {
    let currentStage = onboardingStageDefault.get()
    if currentStage != .onboardingComplete {
        advanceOnboarding(to: .step1_WelcomeIdentity)
    }
}
```

### 2.3 SuspendChat.swift

**POPOPX 增强：**
```swift
// 使用 NSRecursiveLock 替代 DispatchQueue
private let suspendLock = NSRecursiveLock()

// @MainActor 注解确保线程安全
@MainActor
func suspendChat() {
    suspendLock.lock(); defer { suspendLock.unlock() }
    _suspendChat(timeout: appSuspendTimeout)
}

// 异步终止聊天
@MainActor
func terminateChat() async {
    let shouldCloseStore = _terminateChatAction(chatOk: ChatModel.ok)
    if shouldCloseStore {
        await withCheckedContinuation { cont in
            // 异步关闭存储
        }
    }
}
```

**Upstream 标准实现：**
```swift
// 使用专用 DispatchQueue
private let suspendLockQueue = DispatchQueue(label: "chat.simplex.app.suspend.lock")

func suspendChat() {
    suspendLockQueue.sync {
        _suspendChat(timeout: appSuspendTimeout)
    }
}

// 同步终止
func terminateChat() {
    // 同步关闭存储
}
```

---

## 3. POPOPX 独有功能

### 3.1 自定义 Onboarding 流程
- `PXOnboardingCards.swift` - 自定义卡片式 onboarding UI
- `BubbleAnimationComponents.swift` - 气泡动画组件
- `PXAppInfo.swift` - 应用信息展示
- `PXReleaseNotesView.swift` - 版本更新说明

### 3.2 自定义 UI 组件
- `OneHandUICard.swift` - 单手操作卡片
- `PXChatPreviewView.swift` - 聊天预览组件
- `PXServersSummaryView.swift` - 服务器状态汇总
- `GlassAlertView.swift` - 赛博朋克风格 Alert

### 3.3 增强功能
- **Trial 订阅管理：** `SubscriptionManager.swift`
- **Compute Store：** `ComputeStore.swift` (代币购买)
- **Dead Man's Switch：** 安全开关功能
- **Needle Processor：** 本地 AI 处理
- **BitchatMesh：** 离线消息网格

### 3.4 数据库加密增强
- SQLCipher 集成 (上游使用标准 SQLite)
- 自定义密钥管理 (Keychain 存储)
- 迁移事务修复 (2026-10-29)

---

## 4. iOS SDK 适配差异

### 4.1 POPOPX 已修复的弃用 API (2026-10-29)

| 弃用 API | POPOPX 修复方案 | 文件数 |
|---------|----------------|--------|
| `Text("\(var)")` 插值 | `Text(verbatim:)` 或重构 | 8 |
| `UIScreen.main` | `UITraitCollection.current.displayScale` | 2 |
| `CLGeocoder` | `MKReverseGeocodingRequest` | 1 |
| `.previewLayout()` | `#Preview(traits: .fixedLayout)` | 2 |
| `Text + Text` | 字符串插值 | 3 |
| `AVAssetExportSession.status` | 移除状态检查 | 1 |

### 4.2 Upstream 状态
上游代码可能仍使用旧 API，需要同步更新。

---

## 5. 性能优化差异

### 5.1 POPOPX 优化
1. **FFI 队列分离：** 发送和接收使用独立队列，防止阻塞
2. **线程安全增强：** `NSRecursiveLock` + `@MainActor` 注解
3. **异步终止：** `terminateChat()` 改为 async，避免阻塞 UI
4. **自动重试：** 网络错误自动重试机制 (最多 3 次)

### 5.2 Upstream 标准实现
- 使用全局 GCD 队列
- 同步操作为主
- 无自动重试机制

---

## 6. 需要同步的上游更新

### 6.1 高优先级
- [ ] Badge 系统更新 (上游可能有新徽章功能)
- [ ] Call 视图更新 (IncomingCallView 有差异)
- [ ] ChatView 核心逻辑更新

### 6.2 中优先级
- [ ] Onboarding 流程更新 (ChooseServerOperators, CreateProfile)
- [ ] Database 加密视图更新
- [ ] LocalAuthentication 更新

### 6.3 低优先级
- [ ] UI 组件样式更新 (NavLinkPlain, ProfileImage, SwipeLabel)
- [ ] Helper 工具函数更新

---

## 7. 建议

### 7.1 保持 POPOPX 独有特性
- ✅ 自定义 FFI 队列架构 (性能优势)
- ✅ 自动重试机制 (用户体验)
- ✅ Onboarding 状态修复 (稳定性)
- ✅ 赛博朋克 UI 风格 (品牌识别)

### 7.2 需要同步的上游改进
- ⚠️ 检查上游 Badge 系统是否有新功能
- ️ 同步 Call 视图的 bug 修复
- ⚠️ 检查上游是否有新的安全补丁

### 7.3 代码质量建议
- 考虑将 POPOPX 独有功能模块化，便于维护
- 为自定义组件添加单元测试
- 文档化所有与上游的偏离点

---

## 8. 统计

| 指标 | 数值 |
|------|------|
| 差异 Swift 文件数 | ~30 |
| POPOPX 独有文件数 | ~10 |
| 核心架构差异 | 5 处 |
| 性能优化点 | 4 处 |
| UI 自定义组件 | 15+ |

---

**报告生成：** QoderCN  
**下次同步建议：** 检查上游 v7.1.0.15+ 更新
