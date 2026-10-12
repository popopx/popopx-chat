//
//  OnboardingNetworkCommitments.swift
//  POPOPX (iOS)
//
//  Created by POPOPX.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct OnboardingNetworkCommitmentsView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State private var serverOperators: [ServerOperator] = []
    @State private var selectedOperatorIds = Set<Int64>()
    @AppStorage("onboarding_notification_mode") private var notificationModeRaw: String = NotificationsMode.instant.rawValue
    @State private var operatorsLoading = false
    @State private var operatorsLoadFailed = false
    @State private var reloadTask: Task<Void, Never>?
    @State private var operatorsExpanded = false
    @State private var showConditionsSheet = false
    @State private var ageConfirmed = false
    @State private var accepting = false
    @State private var particleExpansionActive = false
    @State private var operatorsLoaded = false

    private var notificationMode: NotificationsMode {
        get { NotificationsMode(rawValue: notificationModeRaw) ?? .instant }
        set { notificationModeRaw = newValue.rawValue }
    }

    private var isConfigComplete: Bool {
        !selectedOperatorIds.isEmpty
    }

    private var canAccept: Bool {
        isConfigComplete && ageConfirmed && !accepting
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .center, spacing: 12) {
                            headerSection

                            routerConfigCard

                            notificationConfigCard

                            bubbleSection

                            commitmentsSection

                            ageCheckbox
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                    .scrollBounceBehavior(.basedOnSize)

                    acceptButton
                        .disabled(!canAccept)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .frame(minHeight: geo.size.height)

                if particleExpansionActive {
                    ParticleExpansionOverlay()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            if !operatorsLoaded {
                operatorsLoaded = true
                serverOperators = ChatModel.shared.conditions.serverOperators
                selectedOperatorIds = Set(serverOperators.filter { $0.enabled }.map { $0.operatorId })
                if serverOperators.isEmpty {
                    reloadOperators()
                }
            }
        }
        .onDisappear {
            reloadTask?.cancel()
            reloadTask = nil
        }
        .onChange(of: notificationModeRaw) { _, newValue in
            ChatModel.shared.notificationMode = NotificationsMode(rawValue: newValue) ?? .instant
        }
        .sheet(isPresented: $showConditionsSheet) {
            NavigationStack {
                VStack {
                    ConditionsTextView()
                        .padding()
                    Spacer(minLength: 0)
                }
                .navigationTitle(NSLocalizedString("Conditions of use", comment: "Conditions of use title"))
                .navigationBarTitleDisplayMode(.large)
                .modifier(ThemedBackground(grouped: true))
            }
        }
        .frame(maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .popopxBranded()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text(NSLocalizedString("Your network", comment: "Your network title"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .tracking(1.0)
                .foregroundColor(.white)
                .shadow(color: Color(hex: "#6E25C4").opacity(0.4), radius: 12, x: 0, y: 2)

            Text(NSLocalizedString("Network routers cannot know\nwho talks to whom", comment: "Network privacy subtitle"))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineSpacing(2)
                .foregroundColor(Color(hex: "#C4BFD6"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    // MARK: - Router Config Card

    private var routerConfigCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    operatorsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack")
                        .foregroundColor(Color(hex: "#00FFD2"))
                    Text(NSLocalizedString("Setup routers", comment: "Setup routers button"))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    Spacer()
                    ForEach(serverOperators.reversed()) { op in
                        Image(op.logo(colorScheme))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .grayscale(selectedOperatorIds.contains(op.operatorId) ? 0.0 : 1.0)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#C4BFD6"))
                        .rotationEffect(.degrees(operatorsExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            if operatorsExpanded {
                VStack(spacing: 8) {
                    if operatorsLoadFailed && serverOperators.isEmpty {
                        Text(NSLocalizedString("Unable to load server operators. Please check your connection and try again.", comment: "operators load error"))
                            .font(.system(size: 13, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(hex: "#C4BFD6"))
                            .padding(.vertical, 8)
                        Button {
                            reloadOperators()
                        } label: {
                            Text(NSLocalizedString("Retry", comment: "retry button"))
                        }
                        .buttonStyle(QuantumButtonStyle(primary: true))
                        .padding(.bottom, 8)
                    } else {
                        ForEach(serverOperators) { srvOperator in
                            inlineOperatorRow(srvOperator)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#141021"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#6E25C4").opacity(0.4), Color(hex: "#00FFD2").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func inlineOperatorRow(_ serverOperator: ServerOperator) -> some View {
        let checked = selectedOperatorIds.contains(serverOperator.operatorId)
        let icon = checked ? "checkmark.circle.fill" : "circle"
        let iconColor = checked ? Color(hex: "#00FFD2") : Color(hex: "#C4BFD6")
        return HStack(spacing: 10) {
            Image(serverOperator.largeLogo(colorScheme))
                .resizable()
                .scaledToFit()
                .frame(height: 32)
            Spacer()
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundColor(iconColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#0D0A16"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    LinearGradient(
                        colors: checked
                            ? [Color(hex: "#6E25C4").opacity(0.5), Color(hex: "#00FFD2").opacity(0.25)]
                            : [Color(hex: "#6E25C4").opacity(0.15), Color(hex: "#00FFD2").opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onTapGesture {
            if checked {
                selectedOperatorIds.remove(serverOperator.operatorId)
            } else {
                selectedOperatorIds.insert(serverOperator.operatorId)
            }
        }
    }

    // MARK: - Notification Config Card

    private var notificationConfigCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "bell.badge")
                    .foregroundColor(Color(hex: "#00FFD2"))
                Text(NSLocalizedString("Notifications", comment: "Notifications config label"))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: notificationMode.icon)
                    .foregroundColor(Color(hex: "#C4BFD6"))
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Picker(NSLocalizedString("Notification mode", comment: "Notification mode picker"), selection: Binding(
                get: { NotificationsMode(rawValue: notificationModeRaw) ?? .instant },
                set: { newValue in notificationModeRaw = newValue.rawValue }
            )) {
                ForEach(NotificationsMode.values) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#141021"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#6E25C4").opacity(0.4), Color(hex: "#00FFD2").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Bubble Section

    private var bubbleSection: some View {
        VStack(spacing: 12) {
            binaryBubble

            Text(NSLocalizedString("Your encrypted bubble", comment: "Bubble label"))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#C4BFD6"))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var binaryBubble: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#00FFD2").opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 40,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 8)

            // Main sphere
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color(hex: "#6E25C4").opacity(0.08),
                            Color(hex: "#0A0A14").opacity(0.6)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 5,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .fill(Color(hex: "#1A1228").opacity(0.5))
                        .opacity(0.5)
                )
                .overlay(
                    // Specular highlight
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.7), Color.white.opacity(0.0)],
                                center: UnitPoint(x: 0.3, y: 0.25),
                                startRadius: 2,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 42)
                        .offset(x: -12, y: -18)
                        .blur(radius: 1.5)
                )
                .overlay(
                    // Gradient border
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#6E25C4"), Color(hex: "#00FFD2")],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            ),
                            lineWidth: 2
                        )
                )
                .compositingGroup()
                .shadow(color: Color(hex: "#00FFD2").opacity(0.35), radius: 15, x: 0, y: 0)

            // Binary data inside bubble
            VStack(spacing: 4) {
                Text(generateBinaryLine())
                Text(generateBinaryLine())
                Text(generateBinaryLine())
            }
            .font(.system(size: 8, design: .monospaced))
            .foregroundColor(Color(hex: "#00FFD2"))
            .opacity(0.7)
        }
    }

    private func generateBinaryLine() -> String {
        let chars = "01"
        return String((0..<16).map { _ in chars.randomElement()! })
    }

    // MARK: - Commitments Section

    private var commitmentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("Network commitments", comment: "Network commitments title"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.white)
                .shadow(color: Color(hex: "#6E25C4").opacity(0.4), radius: 12, x: 0, y: 2)

            HStack(alignment: .top, spacing: 10) {
                commitmentCard(
                    icon: "shield.checkered",
                    title: NSLocalizedString("Operators commit to:", comment: "Operator commitments title"),
                    items: [
                        NSLocalizedString("Be independent", comment: "Operator commitment"),
                        NSLocalizedString("Minimize metadata", comment: "Operator commitment"),
                        NSLocalizedString("Run verified OSS", comment: "Operator commitment"),
                    ]
                )

                commitmentCard(
                    icon: "person.fill.checkmark",
                    title: NSLocalizedString("You commit to:", comment: "User commitments title"),
                    items: [
                        NSLocalizedString("Legal content only", comment: "User commitment"),
                        NSLocalizedString("Respect others", comment: "User commitment"),
                    ]
                )
            }

            Button {
                showConditionsSheet = true
            } label: {
                Text(NSLocalizedString("Privacy policy and conditions of use.", comment: "Privacy policy link"))
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "#00FFD2"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.top, 4)
        }
    }

    private func commitmentCard(icon: String, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#00FFD2"))

            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            ForEach(items, id: \.self) { item in
                HStack(spacing: 4) {
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#00FFD2"))
                    Text(item)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color(hex: "#C4BFD6"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#141021"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#6E25C4").opacity(0.3), Color(hex: "#00FFD2").opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Age Checkbox

    private var ageCheckbox: some View {
        Button {
            ageConfirmed.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: ageConfirmed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(ageConfirmed ? Color(hex: "#00FFD2") : Color(hex: "#C4BFD6"))
                Text(NSLocalizedString("I confirm that I am at least 13 years of age", comment: "COPPA age verification"))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Accept & Enter Button

    private var acceptButton: some View {
        Button {
            handleAcceptAndEnter()
        } label: {
            HStack(spacing: 10) {
                if accepting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 16, weight: .semibold))
                    Text(NSLocalizedString("ACCEPT & ENTER THE BUBBLE", comment: "Accept and enter button"))
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .tracking(1.2)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#2D1B5E").opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#6E25C4").opacity(0.6),
                                        Color(hex: "#8B5CF6").opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(hex: "#6E25C4").opacity(0.8),
                                Color(hex: "#00FFD2").opacity(0.5),
                                Color(hex: "#6E25C4").opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
            )
            .compositingGroup()
            .shadow(color: Color(hex: "#6E25C4").opacity(0.4), radius: 10, x: 0, y: 3)
        }
        .opacity(canAccept ? 1.0 : 0.5)
        .scaleEffect(accepting ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: accepting)
    }

    // MARK: - Actions

    private func handleAcceptAndEnter() {
        guard canAccept else { return }
        accepting = true

        Task { @MainActor in
            _ = await applyNotificationMode()

            do {
                var conditionsId = ChatModel.shared.conditions.currentConditions.conditionsId
                var opIds = Array(selectedOperatorIds)
                let modelOps = ChatModel.shared.conditions.serverOperators
                if opIds.isEmpty && !modelOps.isEmpty {
                    opIds = modelOps.filter { $0.enabled }.map { $0.operatorId }
                }
                if conditionsId == 0 || opIds.isEmpty {
                    let fresh = try await apiGetServerOperators()
                    await MainActor.run { ChatModel.shared.conditions = fresh }
                    conditionsId = fresh.currentConditions.conditionsId
                    if opIds.isEmpty {
                        opIds = fresh.serverOperators.filter { $0.enabled }.map { $0.operatorId }
                    }
                }
                guard !opIds.isEmpty else {
                    throw ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_no_operators_available", comment: "Error when no operators available")))
                }
                guard conditionsId > 0 else {
                    throw ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_invalid_conditions_id", comment: "Error message when conditions ID is invalid")))
                }
                if let validatedOps = enabledOperators(modelOps) {
                    await MainActor.run { ChatModel.shared.conditions.serverOperators = validatedOps }
                }
                let r = try await acceptConditions(conditionsId: conditionsId, operatorIds: opIds)
                await MainActor.run {
                    ChatModel.shared.conditions = r
                }
            } catch {
                accepting = false
                showAlert(
                    NSLocalizedString("Error accepting conditions", comment: "alert title"),
                    message: responseError(error)
                )
                return
            }

            withAnimation(.easeOut(duration: 0.4)) {
                particleExpansionActive = true
            }

            try? await Task.sleep(nanoseconds: 1_200_000_000)

            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        dismissAllSheets(animated: false)
        NtfManager.shared.requestAuthorization(
            onDeny: {
                DispatchQueue.main.async {
                    TransportManager.shared.requestBluetoothPermission {
                        DispatchQueue.main.async {
                            advanceOnboarding(to: .onboardingComplete)
                        }
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 10_000_000000)
                        if !Task.isCancelled && ChatModel.shared.onboardingStage != .onboardingComplete {
                            advanceOnboarding(to: .onboardingComplete)
                        }
                    }
                }
            },
            onAuthorized: {
                DispatchQueue.main.async {
                    TransportManager.shared.requestBluetoothPermission {
                        DispatchQueue.main.async {
                            advanceOnboarding(to: .onboardingComplete)
                        }
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 10_000_000000)
                        if !Task.isCancelled && ChatModel.shared.onboardingStage != .onboardingComplete {
                            advanceOnboarding(to: .onboardingComplete)
                        }
                    }
                }
            }
        )
    }

    private func reloadOperators() {
        operatorsLoading = true
        operatorsLoadFailed = false
        reloadTask?.cancel()
        reloadTask = Task {
            do {
                let conditions = try await apiGetServerOperators()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    ChatModel.shared.conditions = conditions
                    serverOperators = conditions.serverOperators
                    selectedOperatorIds = Set(serverOperators.filter { $0.enabled }.map { $0.operatorId })
                    operatorsLoading = false
                    if serverOperators.isEmpty { operatorsLoadFailed = true }
                }
            } catch {
                logger.error("Failed to reload server operators: \(responseError(error))")
                await MainActor.run {
                    operatorsLoading = false
                    operatorsLoadFailed = true
                }
            }
        }
    }

    private func applyNotificationMode() async -> Bool {
        let m = ChatModel.shared
        m.notificationMode = notificationMode

        if let token = m.deviceToken {
            switch notificationMode {
            case .off:
                m.tokenStatus = .new
                return true
            default:
                do {
                    let status = try await apiRegisterToken(token: token, notificationMode: notificationMode)
                    m.tokenStatus = status
                    return true
                } catch let error {
                    logger.error("applyNotificationMode: token registration failed, will retry later: \(responseError(error))")
                    m.tokenStatus = .new
                    return true
                }
            }
        } else {
            logger.warning("applyNotificationMode: device token not yet available, saving preference for later registration")
            return true
        }
    }

    private func enabledOperators(_ operators: [ServerOperator]) -> [ServerOperator]? {
        var ops = operators
        if !ops.isEmpty {
            for i in 0..<ops.count {
                var op = ops[i]
                op.enabled = selectedOperatorIds.contains(op.operatorId)
                ops[i] = op
            }
            let haveSMPStorage = ops.contains(where: { $0.enabled && $0.smpRoles.storage })
            let haveSMPProxy = ops.contains(where: { $0.enabled && $0.smpRoles.proxy })
            let haveXFTPStorage = ops.contains(where: { $0.enabled && $0.xftpRoles.storage })
            let haveXFTPProxy = ops.contains(where: { $0.enabled && $0.xftpRoles.proxy })
            if haveSMPStorage && haveSMPProxy && haveXFTPStorage && haveXFTPProxy {
                return ops
            } else if let firstEnabledIndex = ops.firstIndex(where: { $0.enabled }) {
                var op = ops[firstEnabledIndex]
                if !haveSMPStorage { op.smpRoles.storage = true }
                if !haveSMPProxy { op.smpRoles.proxy = true }
                if !haveXFTPStorage { op.xftpRoles.storage = true }
                if !haveXFTPProxy { op.xftpRoles.proxy = true }
                ops[firstEnabledIndex] = op
                return ops
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}
