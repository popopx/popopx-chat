// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case chats, contacts, discover, mesh

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .chats: LocalizedStringKey(NSLocalizedString("tab_chats", comment: "Chats tab"))
        case .contacts: LocalizedStringKey(NSLocalizedString("tab_contacts", comment: "Contacts tab"))
        case .discover: LocalizedStringKey(NSLocalizedString("tab_discover", comment: "Discover tab"))
        case .mesh: LocalizedStringKey(NSLocalizedString("tab_mesh", comment: "Mesh tab"))
        }
    }

    var icon: String {
        switch self {
        case .chats: "balloon.fill"
        case .contacts: "person.2.fill"
        case .discover: "safari.fill"
        case .mesh: "network"
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var activeUserPickerSheet: UserPickerSheet?
    @StateObject private var saveableSettings = SaveableSettings()
    @SceneStorage("selectedTab") private var selectedTab: MainTab = .chats
    @State private var showProfileSheet = false
    @StateObject private var blowDetector = MicrophoneBlowDetector()
    @State private var showCenterBalloon = false
    @State private var showOneTimeLink = false
    @State private var oneTimeLinkWorkItem: DispatchWorkItem?

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if isIPad {
                ipadLayout
            } else {
                iphoneLayout
            }
        }
        .environmentObject(saveableSettings)
        .environmentObject(MotionGravityService.shared)
        .onAppear {
            selectedTab = .chats
            NeonGlassTabBarConfig.apply()
            MotionGravityService.shared.start()
        }
        .onChange(of: scenePhase) { _, phase in
            MotionGravityService.shared.handleScenePhase(phase)
        }
        .onChange(of: chatModel.switchToChatsTab) { _, shouldSwitch in
            if shouldSwitch {
                selectedTab = .chats
                chatModel.switchToChatsTab = false
            }
        }
    }

    private var iphoneLayout: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                chatsTab
                    .tag(MainTab.chats)

                contactsTab
                    .tag(MainTab.contacts)

                discoverTab
                    .tag(MainTab.discover)

                hubTab
                    .tag(MainTab.mesh)
            }
            .tint(QuantumColors.accent)
            .popopxBranded()

            // POPOPX: Hide bottom tab bar when in chat conversation
            if chatModel.chatId == nil {
                CustomCapsuleTabBar(
                    selectedTab: $selectedTab,
                    blowDetector: blowDetector,
                    showCenterBalloon: $showCenterBalloon,
                    onBlowComplete: { inflatedScale in
                        if inflatedScale > 1.5 {
                            let workItem = DispatchWorkItem {
                                showOneTimeLink = true
                            }
                            oneTimeLinkWorkItem = workItem
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                        }
                    }
                )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            ScreenshotDefenseOverlay()

            // POPOPX: Center balloon overlay when blowing into mic
            if showCenterBalloon {
                centerBalloonOverlay
            }
        }
        .sheet(isPresented: $showOneTimeLink) {
            NavigationStack {
                PXNewChat(selection: .invite, hidePicker: true)
                    .modifier(ThemedBackground(grouped: true))
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onDisappear {
            oneTimeLinkWorkItem?.cancel()
        }
    }

    private var ipadLayout: some View {
        ZStack {
            NavigationSplitView {
            List {
                ForEach(MainTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.icon)
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("app_name_popopx", comment: "App name"))
            .listStyle(.sidebar)
            .tint(QuantumColors.accent)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            NavigationStack {
                ChatListView(activeUserPickerSheet: $activeUserPickerSheet, onSwitchToProfileTab: {
                    showProfileSheet = true
                }, onSwitchToMesh: {
                    selectedTab = .mesh
                }, onSwitchToDiscover: {
                    selectedTab = .discover
                })
                .navigationDestination(for: MainTab.self) { tab in
                    switch tab {
                    case .chats:
                        ChatListView(activeUserPickerSheet: $activeUserPickerSheet, onSwitchToProfileTab: {
                            showProfileSheet = true
                        }, onSwitchToMesh: {
                            selectedTab = .mesh
                        }, onSwitchToDiscover: {
                            selectedTab = .discover
                        })
                    case .contacts:
                        PXContactsTabView(onBackToHome: {
                            selectedTab = .chats
                        })
                        .environmentObject(chatModel)
                        .environmentObject(theme)
                    case .discover:
                        PXDiscoverTabView(onBackToHome: {
                            selectedTab = .chats
                        })
                        .environmentObject(chatModel)
                        .environmentObject(theme)
                    case .mesh:
                        MeshHubView(chatModel: chatModel, onBackToHome: {
                            selectedTab = .chats
                        })
                    }
                }
            }
        }
        .tint(QuantumColors.accent)
        .popopxBranded()
        .sheet(isPresented: $showProfileSheet) {
            ProfileTabView(onBackToHome: {
                showProfileSheet = false
            })
            .environmentObject(chatModel)
            .environmentObject(theme)
        }

            ScreenshotDefenseOverlay()
        }
    }

    private var chatsTab: some View {
        NavigationStack(path: Binding(
            get: { chatModel.chatId != nil ? [true] : [] },
            set: { path in
                if path.isEmpty { chatModel.chatId = nil }
            }
        )) {
            ChatListView(activeUserPickerSheet: $activeUserPickerSheet, onSwitchToProfileTab: {
                showProfileSheet = true
            }, onSwitchToMesh: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    selectedTab = .mesh
                }
            }, onSwitchToDiscover: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    selectedTab = .discover
                }
            })
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileTabView(onBackToHome: {
                showProfileSheet = false
            })
            .environmentObject(chatModel)
            .environmentObject(theme)
        }
    }

    private var contactsTab: some View {
        NavigationStack {
            PXContactsTabView(onBackToHome: {
                selectedTab = .chats
            })
            .environmentObject(chatModel)
            .environmentObject(theme)
        }
    }

    private var discoverTab: some View {
        NavigationStack {
            PXDiscoverTabView(onBackToHome: {
                selectedTab = .chats
            })
            .environmentObject(chatModel)
            .environmentObject(theme)
        }
    }

    private var hubTab: some View {
        NavigationStack {
            MeshHubView(chatModel: chatModel, onBackToHome: {
                selectedTab = .chats
            })
        }
    }

    // MARK: - POPOPX: Balloon blow overlay
    private var centerBalloonOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                balloon3D
                    .scaleEffect(blowDetector.currentScale)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
            }
        }
        .ignoresSafeArea()
    }

    private var balloon3D: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#A855F7"), Color(hex: "#6E25C4"), Color(hex: "#4A1A8A")],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 2,
                        endRadius: 28
                    )
                )
                .frame(width: 80, height: 80)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.35), .clear],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 14
                    )
                )
                .frame(width: 40, height: 28)
                .offset(x: -12, y: -16)

            Path { p in
                p.move(to: CGPoint(x: 16, y: 36))
                p.addQuadCurve(to: CGPoint(x: 64, y: 44), control: CGPoint(x: 40, y: 56))
            }
            .stroke(Color.white.opacity(0.08), lineWidth: 1)

            Path { p in
                p.move(to: CGPoint(x: 24, y: 24))
                p.addQuadCurve(to: CGPoint(x: 56, y: 60), control: CGPoint(x: 48, y: 36))
            }
            .stroke(Color.white.opacity(0.06), lineWidth: 1)

            Circle()
                .fill(Color(hex: "#6E25C4"))
                .frame(width: 12, height: 12)
                .offset(y: 46)
        }
        .shadow(color: Color(hex: "#6E25C4").opacity(0.5), radius: 20)
        .shadow(color: Color(hex: "#00FFD2").opacity(0.3), radius: 30)
    }
}

struct CustomCapsuleTabBar: View {
    @Binding var selectedTab: MainTab
    @ObservedObject var blowDetector: MicrophoneBlowDetector
    @Binding var showCenterBalloon: Bool
    var onBlowComplete: (CGFloat) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .medium))
                            .minimumScaleFactor(0.5)
                            .foregroundColor(selectedTab == tab ? Color(hex: "#6E25C4") : Color(white: 0.75))
                            .shadow(color: selectedTab == tab ? Color(hex: "#6E25C4").opacity(0.5) : .clear, radius: 4)

                        Text(tab.title)
                            .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                            .minimumScaleFactor(0.5)
                            .foregroundColor(selectedTab == tab ? Color(hex: "#6E25C4") : Color(white: 0.75))

                        NeonTabIndicator(isActive: selectedTab == tab)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .modifier(
                    ChatTabLongPressModifier(
                        isChatsTab: tab == .chats,
                        blowDetector: blowDetector,
                        showCenterBalloon: $showCenterBalloon,
                        onBlowComplete: onBlowComplete
                    )
                )
            }
        }
        .background(
            Capsule()
                .fill(Color(hex: "#0D0A16").opacity(0.85))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            Color(hex: "#6E25C4").opacity(0.15),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 4, y: 4)
        )
    }
}

// MARK: - POPOPX: Long-press gesture for Chats tab blow detection
private struct ChatTabLongPressModifier: ViewModifier {
    let isChatsTab: Bool
    @ObservedObject var blowDetector: MicrophoneBlowDetector
    @Binding var showCenterBalloon: Bool
    var onBlowComplete: (CGFloat) -> Void
    @State private var touchStartDate: Date?

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isChatsTab else { return }
                    if touchStartDate == nil {
                        touchStartDate = Date()
                    }
                    // Check if held for 0.3s
                    if let startDate = touchStartDate,
                       Date().timeIntervalSince(startDate) >= 0.3,
                       !blowDetector.isHoldingButton {
                        showCenterBalloon = true
                        blowDetector.startMonitoring()
                    }
                }
                .onEnded { _ in
                    guard isChatsTab else { return }
                    if blowDetector.isHoldingButton {
                        let inflatedScale = blowDetector.currentScale
                        blowDetector.stopMonitoring()
                        showCenterBalloon = false
                        onBlowComplete(inflatedScale)
                    }
                    touchStartDate = nil
                }
        )
    }
}
