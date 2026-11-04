# POPOPX 上游同步报告

**生成时间：** 2026-10-29  
**同步范围：** Call 模块、Badge 模块、FFI 接口一致性检查

---

## 1. FFI 接口一致性检查 ✅

### 1.1 Haskell FFI 导出对比

| FFI 函数 | POPOPX | Upstream | 状态 |
|---------|--------|----------|------|
| `chat_migrate_init_key` | ✅ | ✅ | 一致 |
| `chat_send_cmd_retry` | ✅ | ✅ | 一致 |
| `chat_recv_msg_wait` | ✅ | ✅ | 一致 |
| `cChatMigrateInit_` | ✅ | ✅ | 一致 (仅模块名差异) |

**结论：** FFI 接口完全一致，仅模块命名不同 (`Popopx.Chat.Mobile` vs `Simplex.Chat.Mobile`)

### 1.2 Swift FFI 绑定对比

| 组件 | POPOPX | Upstream | 差异 |
|------|--------|----------|------|
| `chatController` 类型 | `chat_ctrl?` (Optional) | `chat_ctrl` (Non-optional) | ⚠️ POPOPX 更安全 |
| `getChatCtrl()` | 返回 Optional | fatalError if nil | ️ POPOPX 更健壮 |
| 密钥管理 | `SecureData` 类 + 零化 | 无 | ✅ POPOPX 增强 |
| 数据库备份 | `backupCorruptFile()` | 无 | ✅ POPOPX 增强 |
| 初始化锁 | `NSLock` + `DispatchSemaphore` | 简单检查 | ✅ POPOPX 更线程安全 |

**结论：** POPOPX 的 FFI 绑定比上游更安全，增加了：
- 密钥零化 (SecureData)
- 损坏数据库备份
- 线程安全初始化
- Optional 返回类型避免崩溃

---

## 2. Call 模块差异分析

### 2.1 文件对比

| 文件 | POPOPX | Upstream | 差异程度 |
|------|--------|----------|----------|
| `IncomingCallView.swift` | `PXIncomingCallView` | `IncomingCallView` | 🟡 中等 (UI 样式) |
| `ActiveCallView.swift` | `PXActiveCallView` | `ActiveCallView` | 🟡 中等 (UI 样式) |
| `CallController.swift` | `PXCallController` | `CallController` |  小 (仅命名) |

### 2.2 核心功能对比

**POPOPX 增强：**
```swift
// 1. 自定义视觉配置
private enum PXActiveCallConfig {
    static let localVideoWidthRatio: CGFloat = 0.3
    static let profileImageSize: CGFloat = 192
    static let controlButtonSize: CGFloat = 60
    // ... 更多配置
}

// 2. 中国地区检测 (iOS 27 兼容)
nonisolated static let isInChina: Bool = {
    // 使用 Storefront.current (async) 替代 SKStorefront (deprecated)
    Task {
        let code = await Storefront.current?.countryCode ?? ""
        _updateStorefrontCountryCode(code)
    }
    return code == "CHN"
}()

// 3. 音频会话配置
private enum PXCallAudioConfig {
    static let videoCallOptions: AVAudioSession.CategoryOptions = [
        .defaultToSpeaker, .mixWithOthers, .allowBluetoothHFP, .allowAirPlay, .allowBluetoothA2DP
    ]
}

// 4. 定时任务管理
private var pxSuspendWorkItem: DispatchWorkItem? = nil
```

**Upstream 标准实现：**
```swift
// 1. 硬编码值
let width = g.size.width * 0.3
let profileImageSize: CGFloat = 192

// 2. 使用已弃用的 SKStorefront
static let isInChina = SKStorefront().countryCode == "CHN"

// 3. 无音频配置枚举
// 4. 无定时任务管理
```

### 2.3 需要同步的上游更新

**高优先级：**
- ❌ 无关键功能缺失

**中优先级：**
- ⚠️ 检查上游是否有 CallKit 相关 bug 修复
- ⚠️ 检查上游是否有 WebRTC 连接优化

**低优先级：**
-  上游代码更简洁，可考虑简化 POPOPX 的配置枚举

---

## 3. Badge 模块差异分析

### 3.1 文件对比

| 文件 | POPOPX | Upstream | 状态 |
|------|--------|----------|------|
| `BadgeStore.swift` | ✅ | ✅ | 有差异 |
| `BadgeUserPreview.swift` | ✅ | ✅ | 有差异 |
| `BadgesView.swift` | ✅ | ✅ | 有差异 |
| `BadgesHowItWorksView.swift` | ✅ | ✅ | 有差异 |
| `BadgesLedgerView.swift` | ✅ | ✅ | 有差异 |
| `BadgesRedeemCodeView.swift` | ✅ | ✅ | 有差异 |
| `BadgesYourBadgeView.swift` | ✅ | ✅ | 有差异 |
| `BadgesCheckOrderView.swift` | ❌ | ✅ | **缺失** |
| `BadgesChooseBadgeView.swift` | ❌ | ✅ | **缺失** |
| `BadgesHowLongView.swift` | ❌ | ✅ | **缺失** |
| `BadgesPurchaseStateView.swift` | ❌ | ✅ | **缺失** |
| `BadgesPayView.swift` | ✅ | ❌ | POPOPX 独有 |
| `BadgesSupportPopopxView.swift` | ✅ | ❌ | POPOPX 独有 |
| `BadgesYourLevelView.swift` | ✅ | ❌ | POPOPX 独有 |
| `SupportPopopxBanner.swift` | ✅ | ❌ | POPOPX 独有 |

### 3.2 缺失的上游文件 (需要同步)

**1. BadgesCheckOrderView.swift**
- 功能：检查订单状态
- 重要性： 中 (购买流程)

**2. BadgesChooseBadgeView.swift**
- 功能：选择徽章界面
- 重要性：🟡 中 (用户体验)

**3. BadgesHowLongView.swift**
- 功能：显示徽章持有时间
- 重要性：🟢 低 (信息展示)

**4. BadgesPurchaseStateView.swift**
- 功能：购买状态显示
- 重要性：🟡 中 (购买流程)

### 3.3 POPOPX 独有功能

**1. BadgesPayView.swift**
- 自定义支付界面
- 替代上游的 `BadgesPurchaseStateView`

**2. BadgesSupportPopopxView.swift**
- POPOPX 品牌支持页面
- 替代上游的 `BadgesSupportSimplexView`

**3. BadgesYourLevelView.swift**
- 用户等级展示
- POPOPX 独有功能

**4. SupportPopopxBanner.swift**
- 支持 POPOPX 横幅
- 替代上游的 `SupportSimpleXBanner`

---

## 4. JSON 解析一致性检查

### 4.1 ChatTypes.swift 对比

**POPOPX 扩展字段：**
```swift
public struct UserInfo: Codable {
    // 上游字段
    public var userId: Int64
    public var agentUserId: String
    public var userContactId: Int64
    public var localDisplayName: ContactName
    public var profile: LocalProfile
    public var fullPreferences: FullPreferences
    public var activeUser: Bool
    public var activeOrder: Int64
    public var showNtfs: Bool
    public var sendRcptsContacts: Bool
    public var sendRcptsSmallGroups: Bool
    public var autoAcceptMemberContacts: Bool
    public var autoAcceptGroupInvitations: Bool
    
    // POPOPX 新增字段
    public var userMemberProfileUpdatedAt: Date?  // ⚠️ 上游无此字段
    public var viewPwdHash: UserPwdHash?
    public var uiThemes: ThemeModeOverrides?
    public var userChatRelay: Bool
    public var clientService: Bool  // ⚠️ 上游无此字段
}
```

**上游新增类型：**
```swift
// 上游有但 POPOPX 缺失
public enum ChatPeerType: String, Codable {
    case user
    case group
    case channel
    case agent  // ️ POPOPX 缺失
}

public enum ChatLayout: Hashable {
    case classic
    case terminal
    case unknown(String)
}
```

### 4.2 域名声明对比

**POPOPX：**
```swift
public struct PopopxDomainClaim: Codable, Hashable {
    public var domain: String
    public var proof: PopopxDomainProof?
}

public struct PopopxDomainProof: Codable, Hashable {
    public var linkOwnerId: String?
    public var presHeader: String
    public var signature: String
}
```

**Upstream：**
```swift
public struct SimplexDomainClaim: Codable, Hashable {
    public var domain: String
    public var proof: SimplexDomainProof?
}

public struct SimplexDomainProof: Codable, Hashable {
    public var linkOwnerId: String?
    public var presHeader: String
    public var signature: String
}
```

**结论：** 结构完全一致，仅命名不同

---

## 5. 同步建议

### 5.1 高优先级 (立即同步)

**无关键缺失** - POPOPX 的 Call 和 Badge 模块功能完整

### 5.2 中优先级 (建议同步)

**1. Badge 模块缺失文件：**
```bash
# 需要从上游复制的文件
- BadgesCheckOrderView.swift
- BadgesChooseBadgeView.swift
- BadgesPurchaseStateView.swift
```

**2. ChatTypes.swift 更新：**
```swift
// 添加缺失的枚举
public enum ChatPeerType: String, Codable {
    case user
    case group
    case channel
    case agent  // 新增
}

public enum ChatLayout: Hashable {
    case classic
    case terminal
    case unknown(String)
}
```

### 5.3 低优先级 (可选同步)

**1. BadgesHowLongView.swift**
- 功能：显示徽章持有时间
- 影响：用户体验增强

**2. 简化 Call 模块配置**
- 考虑将部分配置枚举合并
- 减少代码复杂度

---

## 6. 风险评估

### 6.1 同步风险

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| Badge 购买流程冲突 | 🟡 中 | 保留 POPOPX 的 BadgesPayView |
| Call 样式覆盖 | 🟢 低 | 仅同步逻辑，保留 POPOPX UI |
| JSON 解析失败 | 🟢 低 | 使用 `decodeIfPresent` 处理可选字段 |

### 6.2 不同步风险

| 风险 | 等级 | 影响 |
|------|------|------|
| 错过上游 bug 修复 | 🟡 中 | Call 稳定性 |
| Badge 功能不完整 | 🟡 中 | 用户体验 |
| 类型系统不一致 | 🟢 低 | 编译警告 |

---

## 7. 行动计划

### Phase 1: Badge 模块同步 (预计 2 小时)
1. 复制缺失的上游文件 (4 个)
2. 重命名 `Simplex` → `Popopx`
3. 调整 UI 样式匹配 POPOPX 主题
4. 测试购买流程

### Phase 2: ChatTypes 更新 (预计 30 分钟)
1. 添加 `ChatPeerType.agent`
2. 添加 `ChatLayout` 枚举
3. 更新 JSON 解析逻辑
4. 测试序列化/反序列化

### Phase 3: Call 模块审查 (预计 1 小时)
1. 检查上游 CallKit bug 修复
2. 评估是否简化配置枚举
3. 测试通话功能

---

## 8. 总结

**FFI 接口：** ✅ 完全一致，POPOPX 更安全  
**Call 模块：** 🟢 功能完整，仅 UI 样式差异  
**Badge 模块：** 🟡 缺失 4 个上游文件，建议同步  
**JSON 解析：** 🟡 基本一致，缺失少量枚举类型  

**总体评估：** POPOPX 代码质量高于上游，建议选择性同步 Badge 模块缺失文件。

---

**报告生成：** QoderCN  
**下一步：** 执行 Phase 1 Badge 模块同步
