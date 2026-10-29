//
// PXUserPicker.swift
// POPOPX - Multi-account user picker with branded styling
// Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// POPOPX customization
private let pxPickerCornerRadius: CGFloat = 16
private let pxPickerShadowRadius: CGFloat = 4

// Spec: spec/client/chat-list.md#UserPicker
struct UserPicker: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dynamicTypeSize) private var userFont: DynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase: ScenePhase
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @Binding var userPickerShown: Bool
    @Binding var activeSheet: UserPickerSheet?
    @State private var currentUser: Int64?
    @State private var switchingProfile = false
    @State private var frameWidth: CGFloat = 0
    @State private var resetScroll = ResetScrollAction()

    // Inset grouped list dimensions
    private let imageSize: CGFloat = 44
    private let rowPadding: CGFloat = 16
    private let rowVerticalPadding: CGFloat = 11
    private let sectionSpacing: CGFloat = 35
    private var sectionHorizontalPadding: CGFloat { frameWidth > 375 ? 20 : 16 }
    private let sectionShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    private var pxPickerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: pxPickerCornerRadius, style: .continuous)
    }

    var body: some View {
        let otherUsers: [UserInfo] = m.users
            .filter { u in !u.user.hidden && u.user.userId != m.currentUser?.userId }
            .sorted(using: KeyPathComparator<UserInfo>(\.user.activeOrder, order: .reverse))
        let sectionWidth = max(frameWidth - sectionHorizontalPadding * 2, 0)
        let currentUserWidth = max(frameWidth - sectionHorizontalPadding - rowPadding * 2 - 14 - imageSize, 0)
        let stopped = m.chatRunning != true
        VStack(spacing: sectionSpacing) {
            if let user = m.currentUser {
                PXStickyScroll(resetScroll: $resetScroll) {
                    HStack(spacing: rowPadding) {
                        HStack {
                            ProfileImage(imageStr: user.image, size: imageSize, color: Color(uiColor: .tertiarySystemGroupedBackground), showTierBadge: true)
                                .padding(.trailing, 6)
                            Text(profileName(user)).lineLimit(1)
                        }
                        .padding(rowPadding)
                        .frame(width: otherUsers.isEmpty ? sectionWidth : currentUserWidth, alignment: .leading)
                        .modifier(ListRow { activeSheet = .currentProfile })
                        .clipShape(pxPickerShape)
                        .disabled(stopped)
                        .opacity(stopped ? 0.4 : 1)
                        ForEach(otherUsers) { u in
                            userView(u, size: imageSize)
                                .frame(maxWidth: sectionWidth * 0.618)
                                .fixedSize()
                                .disabled(stopped)
                                .opacity(stopped ? 0.4 : 1)
                        }
                    }
                    .padding(.horizontal, sectionHorizontalPadding)
                }
                .frame(height: 2 * rowPadding + imageSize)
                .padding(.top, sectionSpacing)
                .overlay(DetermineWidth())
                .onPreferenceChange(DetermineWidth.Key.self) { frameWidth = $0 }
            }
            VStack(spacing: 0) {
                openSheetOnTap("qrcode", title: m.userAddress == nil ? LocalizedStringKey(NSLocalizedString("user_picker_create_address", comment: "Create POPOPX address")) : LocalizedStringKey(NSLocalizedString("user_picker_your_address", comment: "Your POPOPX address")), sheet: .address, disabled: stopped)
                openSheetOnTap("switch.2", title: LocalizedStringKey(NSLocalizedString("user_picker_chat_preferences", comment: "Chat preferences")), sheet: .chatPreferences, disabled: stopped)
                openSheetOnTap("person.crop.rectangle.stack", title: LocalizedStringKey(NSLocalizedString("user_picker_chat_profiles", comment: "Your chat profiles")), sheet: .chatProfiles, disabled: stopped)
                openSheetOnTap("desktopcomputer", title: LocalizedStringKey(NSLocalizedString("user_picker_use_from_desktop", comment: "Use from desktop")), sheet: .useFromDesktop, disabled: stopped)
                ZStack(alignment: .trailing) {
                    openSheetOnTap("gearshape", title: LocalizedStringKey(NSLocalizedString("user_picker_settings", comment: "Settings")), sheet: .settings, showDivider: false)
                    Image(systemName: colorScheme == .light ? "sun.max" : "moon.fill")
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.monochrome)
                        .foregroundColor(theme.colors.secondary)
                        .frame(maxWidth: 20, maxHeight: .infinity)
                        .padding(.horizontal, rowPadding)
                        .background(theme.colors.surface.opacity(0.01))
                        .onTapGesture {
                            if (colorScheme == .light) {
                                ThemeManager.applyTheme(systemDarkThemeDefault.get())
                            } else {
                                ThemeManager.applyTheme(DefaultTheme.LIGHT.themeName)
                            }
                        }
                        .onLongPressGesture {
                            ThemeManager.applyTheme(DefaultTheme.SYSTEM_THEME_NAME)
                        }
                }
            }
            .clipShape(pxPickerShape)
            .padding(.horizontal, sectionHorizontalPadding)
            .padding(.bottom, sectionSpacing)
        }
        .task {
            // This check prevents the call of listUsers after the app is suspended, and the database is closed.
            if case .active = scenePhase, hasChatCtrl() {
                currentUser = m.currentUser?.userId
                do {
                    let users = try await listUsersAsync()
                    await MainActor.run {
                        m.users = users
                        currentUser = m.currentUser?.userId
                    }
                } catch {
                    logger.error("Error loading users \(responseError(error))")
                }
            }
        }
        .onChange(of: userPickerShown) { _, newValue in
            if !newValue { resetScroll() }
        }
        .modifier(ThemedBackground(grouped: true))
        .disabled(switchingProfile)
        .popopxBranded()
    }

    private func userView(_ u: UserInfo, size: CGFloat) -> some View {
        HStack {
            ZStack(alignment: .topTrailing) {
                ProfileImage(imageStr: u.user.image, size: size, color: Color(uiColor: .tertiarySystemGroupedBackground))
                if (u.unreadCount > 0) {
                    userUnreadBadge(u, theme: theme).offset(x: 4, y: -4)
                }
            }
            .padding(.trailing, 6)
            NameWithBadge(Text(u.user.displayName).font(.title2), u.user.profile.localBadge, .title2)
                .lineLimit(1)
        }
        .padding(rowPadding)
        .modifier(ListRow {
            switchingProfile = true
            Task {
                do {
                    try await changeActiveUserAsync_(u.user.userId, viewPwd: nil)
                    await MainActor.run {
                        switchingProfile = false
                        userPickerShown = false
                    }
                } catch {
                    await MainActor.run {
                        switchingProfile = false
                        showAlert(
                            NSLocalizedString("Error switching profile!", comment: "alertTitle"),
                            message: String.localizedStringWithFormat(NSLocalizedString("Error: %@", comment: "alert message"), responseError(error))
                        )
                    }
                }
            }
        })
        .clipShape(pxPickerShape)
    }

    private func openSheetOnTap(_ icon: String, title: LocalizedStringKey, sheet: UserPickerSheet, showDivider: Bool = true, disabled: Bool = false) -> some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 14) {
                // Gradient icon container
                ZStack {
                    Circle()
                        .fill(AnyShapeStyle(LinearGradient(
                            colors: [theme.colors.primary, theme.colors.primaryVariant],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )))
                        .frame(width: 36, height: 36)
                        .shadow(color: theme.colors.primary.opacity(0.3), radius: 6, x: 0, y: 3)
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }
                Text(title)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                    .opacity(disabled ? 0.4 : 1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.colors.secondary.opacity(0.5))
            }
            .padding(.horizontal, rowPadding)
            .padding(.vertical, rowVerticalPadding + 2)
            .modifier(ListRow { activeSheet = sheet })
            .disabled(disabled)
            if showDivider {
                GlassDivider()
                    .padding(.leading, 66)
                    .opacity(0.3)
            }
        }
    }
}

@inline(__always)
func userUnreadBadge(_ userInfo: UserInfo, theme: AppTheme) -> some View {
    UnreadBadge(
        count: userInfo.unreadCount,
        color: userInfo.user.showNtfs ? theme.colors.primary : theme.colors.secondary
    )
}

struct UnreadBadge: View {
    @Environment(\.dynamicTypeSize) private var userFont: DynamicTypeSize
    var count: Int
    var color: Color

    var body: some View {
        let size = dynamicSize(userFont).chatInfoSize
        unreadCountText(count)
            .font(userFont <= .xxxLarge ? .caption : .caption2)
            .foregroundColor(.white)
            .padding(.horizontal, dynamicSize(userFont).unreadPadding)
            .frame(minWidth: size, minHeight: size)
            .background(color)
            .cornerRadius(dynamicSize(userFont).unreadCorner)
    }
}

struct ListRow: ViewModifier {
    @EnvironmentObject var theme: AppTheme
    @State private var touchDown = false
    let action: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            // Premium gradient background
            RoundedRectangle(cornerRadius: pxPickerCornerRadius, style: .continuous)
                .fill(AnyShapeStyle(LinearGradient(
                    colors: [
                        theme.colors.surface.opacity(0.8),
                        theme.colors.surface.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )))
            // Touch feedback overlay with glow
            RoundedRectangle(cornerRadius: pxPickerCornerRadius, style: .continuous)
                .fill(theme.colors.primary.opacity(touchDown ? 0.15 : 0))
                .shadow(color: theme.colors.primary.opacity(touchDown ? 0.3 : 0), radius: pxPickerShadowRadius * 2, x: 0, y: 0)
            content
            TouchOverlay(touchDown: $touchDown, action: action)
        }
        .overlay(
            RoundedRectangle(cornerRadius: pxPickerCornerRadius, style: .continuous)
                .strokeBorder(
                    AnyShapeStyle(LinearGradient(
                        colors: [
                            theme.colors.primary.opacity(0.2),
                            theme.colors.primaryVariant.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )),
                    lineWidth: 0.5
                )
        )
    }

    struct TouchOverlay: UIViewRepresentable {
        @Binding var touchDown: Bool
        let action: () -> Void

        func makeUIView(context: Context) -> TouchView {
            let touchView = TouchView()
            let gesture = UILongPressGestureRecognizer(
                target: touchView,
                action: #selector(touchView.longPress(gesture:))
            )
            gesture.delegate = touchView
            gesture.minimumPressDuration = 0
            touchView.addGestureRecognizer(gesture)
            return touchView
        }

        func updateUIView(_ touchView: TouchView, context: Context) {
            touchView.representer = self
        }

        class TouchView: UIView, UIGestureRecognizerDelegate {
            var representer: TouchOverlay?
            private var startLocation: CGPoint?
            private var task: Task<Void, Never>?

            @objc
            func longPress(gesture: UILongPressGestureRecognizer) {
                switch gesture.state {
                case .began:
                    startLocation = gesture.location(in: nil)
                    task = Task {
                        do {
                            try await Task.sleep(nanoseconds: 200_000000)
                            await MainActor.run { representer?.touchDown = true }
                        } catch {
                            logger.error("UserPicker: Task.sleep failed: \(error.localizedDescription)")
                        }
                    }
                case .ended:
                    if hitTest(gesture.location(in: self), with: nil) == self {
                        representer?.action()
                    }
                    task?.cancel()
                    representer?.touchDown = false
                case .changed:
                    if let startLocation {
                        let location = gesture.location(in: nil)
                        let dx = location.x - startLocation.x
                        let dy = location.y - startLocation.y
                        if sqrt(pow(dx, 2) + pow(dy, 2)) > 10 { gesture.state = .failed }
                    }
                case .cancelled, .failed:
                    task?.cancel()
                    representer?.touchDown = false
                default: break
                }
            }

            func gestureRecognizer(
                _: UIGestureRecognizer,
                shouldRecognizeSimultaneouslyWith: UIGestureRecognizer
            ) -> Bool { true }
        }
    }
}

// MARK: - POPOPX
extension UserPicker {
    static let pxComponentTag: String = "PX_USER_PICKER"
    static let pxIconContainerSize: CGFloat = 36
    static let pxDividerOpacity: CGFloat = 0.3

    func pxProfileBadge() -> some View {
        Image(systemName: "checkmark.seal.fill")
            .foregroundStyle(theme.colors.primary)
            .font(.caption)
    }

    func pxPickerCardShadow() -> some ViewModifier {
        PxPickerCardShadow(radius: pxPickerShadowRadius)
    }
}

private struct PxPickerCardShadow: ViewModifier {
    @EnvironmentObject var theme: AppTheme
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.shadow(
            color: theme.colors.primary.opacity(0.08),
            radius: radius,
            x: 0, y: 2
        )
    }
}

struct UserPicker_Previews: PreviewProvider {
    static var previews: some View {
        @State var activeSheet: UserPickerSheet?

        let m = ChatModel()
        m.users = [UserInfo.sampleData, UserInfo.sampleData]
        return UserPicker(
            userPickerShown: .constant(true),
            activeSheet: $activeSheet
        )
        .environmentObject(m)
    }
}
