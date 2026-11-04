---
name: project-ios-sdk-deprecation-fixes-2026-10-29
description: iOS 26/27 SDK deprecation fixes for Xcode compilation
metadata:
  type: project
---

## iOS 26/27 SDK Deprecation Fixes (2026-10-29)

### LocalizedStringKey Interpolation (8 occurrences)
**Problem:** `Text("\(variable)")` with interpolation deprecated
**Fix:** Use `Text(verbatim:)` for pre-localized strings, or restructure

Files fixed:
- `SetNotificationsMode.swift:247` — `Text("\(Image...)")` → `Label(mode.label, systemImage: mode.icon)`
- `PXActiveCallView.swift:570,602` — `Text("(\(connInfo.text))")` → `Text(verbatim:)`
- `PXIntegrityErrorItemView.swift:33` — `Text("\(NSLoc...)")` → `Text(verbatim:)`
- `PXServersSummaryView.swift:643` — `Text("\(title) / \(title2)")` → `HStack(spacing: 0)` with separate Text views
- `PXServersSummaryView.swift:649` — `Text("\(numOrDash...)")` → `Text(verbatim:)`
- `OneHandUICard.swift:207` — `Text("\(stateKey)...")` → `Text(verbatim:)`
- `PXPreferencesView.swift:130` — `Text("\(featureDescription)...")` → `Text(verbatim:)`

### UIScreen.main Deprecated (2 occurrences)
**Problem:** `UIScreen.main` unavailable in app extensions
**Fix:** Use `UITraitCollection.current.displayScale` or fixed values

Files fixed:
- `PXShareSheet.swift:26` — `UIScreen.main.scale` → `UITraitCollection.current.displayScale`
- `ImageUtils.swift:51` — `UIScreen.main.bounds.width * UIScreen.main.scale` → fixed `390 * UITraitCollection.current.displayScale`

### CLGeocoder Deprecated (1 occurrence)
**Problem:** `CLGeocoder().reverseGeocodeLocation()` deprecated in iOS 26.0
**Fix:** Use `MKReverseGeocodingRequest` from MapKit

File fixed:
- `LocationSharing.swift:120-134` — Replaced with `MKReverseGeocodingRequest(location:)` + `request.mapItems`, using `MKMapItem.name` and `MKMapItem.address?.shortAddress`

### previewLayout Deprecated (2 occurrences)
**Problem:** `.previewLayout(.fixed(...))` modifier deprecated
**Fix:** Use `#Preview(traits: .fixedLayout(...))` macro

Files fixed:
- `PXCIMetaView.swift:241-254` — Converted `PreviewProvider` to `#Preview(traits: .fixedLayout(width: 360, height: 100))`
- `PXChatPreviewView.swift:767-800` — Converted to `#Preview(traits: .fixedLayout(width: 360, height: 78))`

### Text '+' Operator Deprecated (1 occurrence)
**Problem:** `Text + Text` concatenation deprecated
**Fix:** Change function return type from `Text` to `String`, use string interpolation

Files fixed:
- `PXGroupChatMemberActions.swift:92` — `deleteGroupAlertMessage` returns `String` instead of `Text`
- `PXGroupChatInfoView.swift:870` — `Text("\(displayName)\n\n\(message)")` interpolation
- `PXChatListNavLink.swift:718` — Updated caller to wrap String in `Text()`

### AVAssetExportSession.status Deprecated (1 occurrence)
**Problem:** `s.status == .completed` check deprecated
**Fix:** Remove status check; `export()` throws on failure so reaching return means success

File fixed:
- `ImageUtils.swift:375` — Removed `return s.status == .completed`, now just `return true` after successful export

### Verification
- Build succeeds with zero errors and zero deprecation warnings
- App launches and shows onboarding screen correctly
- Tested on iOS 27.0 simulator (iPhone 17)
