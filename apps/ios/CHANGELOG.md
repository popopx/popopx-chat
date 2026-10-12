# Changelog

All notable changes to the POPOPX iOS app are documented in this file.

## [Unreleased]

### 2026-09-11 — Neon Noir Viral UI System

**Commit:** `d63ad4607`

#### Added

**Transient Bubbles** — message-level visual interactions:
- Iridescent bubble skin with TimelineView + Canvas sinusoidal light bands
- Pop explosion particle system (200-500 particles with gravity, drag, and air resistance)
- CoreHaptics engine: `popAuto()`, `popManual()`, `popLargeFile()`, `swipeTrail()` patterns
- Swipe-to-pop gesture on timed messages (horizontal drag > 60% bubble width)
- Connection bubble with long-press throw-to-share interaction
- Needle bubble guard: regex-based sensitive content detection (phone/email/ID/bank card) with needle pierce animation

**Neon Noir** — app-level aesthetic overhaul:
- Neon glass tab bar: `ultraThinMaterial` + `#0F0B1E` 60% tint, gradient capsule indicators, spring icon animations
- Ambient orb background: 4 slow-drifting color spheres (violet/cyan/magenta/indigo) with 80pt blur
- Glow avatar ring: rotating `AngularGradient` (8s period) with outer blur glow
- Profile glass cards: `ultraThinMaterial` + `#1C1635` tint + 0.5pt gradient border
- Send ripple effect: 3 concentric expanding circles (cyan/violet/magenta)
- Receive glow effect: pulsing violet border on new messages
- Neon launch splash: breathing "POPOPX" logo with triple shadow glow + ambient drift orbs

#### Feature Flags

| Key | Default | Effect |
|-----|---------|--------|
| `PX_TRANSIENT_BUBBLES_ENABLED` | `false` | Enables iridescent bubble skin on chat messages |
| `PX_SWIPE_TO_POP_ENABLED` | `false` | Enables swipe-to-pop gesture on timed messages |

#### Accessibility

All animations respect `\.accessibilityReduceMotion`:
- Ambient orbs freeze to static positions
- Avatar ring becomes a static gradient
- Bubble light bands freeze to a static gradient
- Particle explosions and haptic patterns are skipped

#### Files (19 changed, +1668 lines)

New:
- `Shared/Customization/GenerativeArt/UI/BubbleIridescentSkin.swift`
- `Shared/Customization/GenerativeArt/UI/BubblePopExplosion.swift`
- `Shared/Customization/GenerativeArt/UI/BubbleHapticsManager.swift`
- `Shared/Customization/GenerativeArt/UI/ConnectionBubble.swift`
- `Shared/Customization/GenerativeArt/UI/MessageSendEffects.swift`
- `Shared/Customization/Needle/NeedleBubbleGuard.swift`
- `Shared/Customization/Theme/NeonGlassTabBar.swift`
- `Shared/Customization/Theme/ChatListAmbient.swift`
- `Shared/Customization/Theme/ProfileGlowAvatar.swift`
- `Shared/Customization/Theme/NeonLaunchSplash.swift`

Modified:
- `Shared/Views/RootTabView.swift` — tab bar neon config
- `Shared/Views/ChatList/ChatListView.swift` — ambient orb background
- `Shared/Views/Profile/ProfileTabView.swift` — glow avatar ring
- `Shared/Views/Chat/ChatItem/PXFramedItemView.swift` — iridescent modifier integration
- `Shared/Views/Chat/ChatItemWithMenu.swift` — swipe-to-pop gesture
- `Shared/Views/Helpers/PXChatItemClipShape.swift` — unread/TTL properties
- `Shared/POPOPXApp.swift` — launch splash overlay
- `Shared/Customization/GenerativeArt/UI/GenerativeArtChatModifiers.swift` — non-Cyber iridescent
- `POPOPX.xcodeproj/project.pbxproj` — 5 new file references + build phase entries
