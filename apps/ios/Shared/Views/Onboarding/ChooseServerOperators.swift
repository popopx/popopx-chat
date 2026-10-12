//
//  ChooseServerOperators.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 31.10.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/navigation.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// Terms and conditions URL for server operators.
// Currently hardcoded; consider fetching from a remote config endpoint (servers/config)
// to allow updates without requiring an app release.
let conditionsURL = URL(string: "https://popopxchat.com/conditions") ?? URL(filePath: "/")

struct OnboardingButtonStyle: ButtonStyle {
    @EnvironmentObject var theme: AppTheme
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                isDisabled
                ? (
                    theme.colors.isLight
                    ? .gray.opacity(0.17)
                    : .gray.opacity(0.27)
                )
                : theme.colors.primary
            )
            .foregroundColor(
                isDisabled
                ? (
                    theme.colors.isLight
                    ? .gray.opacity(0.4)
                    : .white.opacity(0.2)
                )
                : .white
            )
            .cornerRadius(10)
            .shadow(color: darkThemeAccentColor().opacity(0.15), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct OnboardingConditionsView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State private var showConditionsSheet = false
    @State private var accepting = false
    @State private var ageConfirmed = false
    @State private var selectedOperatorIds: Set<Int64>
    @State private var operatorsLoaded = false
    @State private var operatorFetchError = false
    @StateObject private var popController = BubblePopController()
    @State private var showBubble = false

    init(initialOperatorIds: Set<Int64> = []) {
        _selectedOperatorIds = State(initialValue: initialOperatorIds)
    }

    var body: some View {
        ZStack {
            OnboardingBubbleBackground()

            GeometryReader { g in
                VStack(alignment: .leading, spacing: 10) {
                    Spacer(minLength: 0)

                    conditionsBubbleContent(g: g)

                    if operatorFetchError {
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("Unable to load server operators. Please check your connection and try again.", comment: "Operator fetch error message"))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(hex: "#C4BFD6"))
                            .multilineTextAlignment(.center)
                        Button {
                            retryFetchOperators()
                        } label: {
                            Text(NSLocalizedString("Retry", comment: "Retry button"))
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(QuantumButtonStyle(primary: true))
                    }
                    .padding(.vertical, 8)
                }

                Text(NSLocalizedString("Network commitments", comment: "Network commitments title"))
                    .font(.system(.title, design: .default).weight(.bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.white)
                    .shadow(color: Color(hex: "#6E25C4").opacity(0.4), radius: 12, x: 0, y: 2)

                Text(NSLocalizedString("Operators commit to:\n- Be independent\n- Minimize metadata usage\n- Run verified open-source code", comment: "Operator commitments"))
                    .font(.system(size: 14, design: .monospaced))
                    .lineSpacing(4)
                    .foregroundColor(Color(hex: "#C4BFD6"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)

                Text(NSLocalizedString("You commit to:\n- Only legal content in public groups\n- Respect other users - no spam", comment: "User commitments"))
                    .font(.system(size: 14, design: .monospaced))
                    .lineSpacing(4)
                    .foregroundColor(Color(hex: "#C4BFD6"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)

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
                .padding(.top, 10)
                .padding(.bottom, 15)

                Spacer(minLength: 0)

                Button {
                    ageConfirmed.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: ageConfirmed ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(ageConfirmed ? Color(hex: "#00FFD2") : Color(hex: "#C4BFD6"))
                        Text(NSLocalizedString("I confirm that I am at least 13 years of age", comment: "COPPA age verification"))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 8)

                acceptButton()
                    .frame(maxWidth: .infinity)
                    .disabled(!ageConfirmed)
                    .safeAreaPadding(.bottom, 20)
            }
                .padding(.horizontal, 25)
                .padding(.top, 25)
                .padding(.bottom, 25)
                .frame(maxHeight: .infinity)

                PurpleFlashOverlay(isActive: popController.flashActive)
            }
        }
        .frame(maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !operatorsLoaded else { return }
            operatorsLoaded = true
            if selectedOperatorIds.isEmpty {
                let modelOps = ChatModel.shared.conditions.serverOperators
                if !modelOps.isEmpty {
                    selectedOperatorIds = Set(modelOps.filter { $0.enabled }.map { $0.operatorId })
                } else {
                    Task {
                        await MainActor.run { operatorFetchError = false }
                        do {
                            let conditions = try await apiGetServerOperators()
                            await MainActor.run {
                                ChatModel.shared.conditions = conditions
                                selectedOperatorIds = Set(conditions.serverOperators.filter { $0.enabled }.map { $0.operatorId })
                            }
                        } catch {
                            logger.error("OnboardingConditionsView: failed to reload server operators: \(responseError(error))")
                            await MainActor.run { operatorFetchError = true }
                        }
                    }
                }
            }
        }
        .onDisappear {
            popController.reset()
        }
        .sheet(isPresented: $showConditionsSheet) {
            NavigationStack {
                VStack {
                    ConditionsTextView()
                        .padding()
                    Spacer(minLength: 0)
                    Button {
                        ageConfirmed.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: ageConfirmed ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(theme.colors.secondary)
                            Text(NSLocalizedString("I confirm that I am at least 13 years of age", comment: "COPPA age verification"))
                                .font(.callout)
                                .foregroundColor(isInDarkTheme() ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 12)
                    acceptButton()
                        .frame(maxWidth: .infinity)
                        .disabled(!ageConfirmed)
                        .padding(.horizontal, 25)
                        .padding(.bottom, 20)
                }
                .navigationTitle(NSLocalizedString("Conditions of use", comment: "Conditions of use title"))
                .navigationBarTitleDisplayMode(.large)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing, content: conditionsLinkButton) }
                .modifier(ThemedBackground(grouped: true))
            }
        }
    }

    private func conditionsBubbleContent(g: GeometryProxy) -> some View {
        ZStack {
            if popController.isPopping {
                BubblePopCanvas(particles: popController.particles)
                    .frame(width: g.size.width, height: 180)
            } else {
                ZStack(alignment: .bottomTrailing) {
                    // Use XBalloon3D instead of CompactBubble3D for Accept animation
                    XBalloon3D(diameter: min(160, g.size.width * 0.4))
                        .scaleEffect(showBubble ? 1.0 : 0.8)
                        .opacity(showBubble ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showBubble)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showBubble = true
                            }
                        }
                        .onTapGesture {
                            triggerConditionsPop(in: g)
                        }

                    if showBubble {
                        FingerTapAnimation(onPop: { triggerConditionsPop(in: g) })
                            .offset(x: 10, y: 10)
                            .transition(.opacity.combined(with: .scale))
                    }
                }

                if !popController.isPopping && showBubble {
                    Text(NSLocalizedString("tap_commitments_hint", comment: "Hint text for commitments bubble"))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#C4BFD6"))
                        .offset(y: 100)
                }
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
    }

    private func triggerConditionsPop(in g: GeometryProxy) {
        popController.triggerPop(
            containerSize: g.size,
            bubbleCenterY: 90,
            style: .commitments,
            onComplete: {}
        )
    }

    private func triggerConditionsPopForAccept() {
        let screenWidth: CGFloat = {
            if let ws = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return ws.windows.first?.bounds.width ?? 390
            }
            return 390
        }()
        popController.triggerPop(
            containerSize: CGSize(width: screenWidth, height: 800),
            bubbleCenterY: 90,
            style: .commitments,
            onComplete: {}
        )
    }

    private func acceptButton() -> some View {
        Button {
            guard !accepting else { return }
            accepting = true
            triggerConditionsPopForAccept()
            Task {
                do {
                    var conditionsId = ChatModel.shared.conditions.currentConditions.conditionsId
                    var opIds = Array(selectedOperatorIds)
                    let modelOps = ChatModel.shared.conditions.serverOperators
                    if opIds.isEmpty && !modelOps.isEmpty {
                        opIds = modelOps.filter { $0.enabled }.map { $0.operatorId }
                        logger.debug("acceptButton: using model operators, opIds=\(opIds)")
                    }
                    if conditionsId == 0 || opIds.isEmpty {
                        logger.debug("acceptButton: reloading conditions from server")
                        let fresh = try await apiGetServerOperators()
                        await MainActor.run { ChatModel.shared.conditions = fresh }
                        conditionsId = fresh.currentConditions.conditionsId
                        if opIds.isEmpty {
                            opIds = fresh.serverOperators.filter { $0.enabled }.map { $0.operatorId }
                        }
                    }
                    logger.debug("acceptButton: conditionsId=\(conditionsId), opIds=\(opIds), count=\(opIds.count)")
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
                    // acceptConditions already updates the database with accepted operators
                    // No need to call setServerOperators again - it causes "Failed reading: empty" error
                    await MainActor.run {
                        ChatModel.shared.conditions = r
                        completeOnboarding()
                    }
                } catch let error {
                    await MainActor.run {
                        accepting = false
                        showAlert(
                            NSLocalizedString("Error accepting conditions", comment: "alert title"),
                            message: responseError(error)
                        )
                    }
                }
            }
        } label: {
            Text(NSLocalizedString("Accept", comment: "Accept button"))
        }
        .buttonStyle(QuantumButtonStyle(primary: true))
        .disabled(selectedOperatorIds.isEmpty || !ageConfirmed || accepting)
    }

    private func retryFetchOperators() {
        operatorFetchError = false
        Task {
            do {
                let conditions = try await apiGetServerOperators()
                await MainActor.run {
                    ChatModel.shared.conditions = conditions
                    selectedOperatorIds = Set(conditions.serverOperators.filter { $0.enabled }.map { $0.operatorId })
                }
            } catch {
                logger.error("OnboardingConditionsView: retry failed: \(responseError(error))")
                await MainActor.run { operatorFetchError = true }
            }
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

private enum ChooseServerOperatorsSheet: Identifiable {
    case showInfo

    var id: String {
        switch self {
        case .showInfo: return "showInfo"
        }
    }
}

struct ChooseServerOperators: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var m: ChatModel
    var serverOperators: [ServerOperator]
    @Binding var selectedOperatorIds: Set<Int64>
    @State private var sheetItem: ChooseServerOperatorsSheet? = nil

    var body: some View {
        ZStack {
            OnboardingBubbleBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(NSLocalizedString("Server operators", comment: "Server operators title"))
                        .font(.system(.title, design: .default).weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 25)
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: "#6E25C4").opacity(0.4), radius: 10, x: 0, y: 2)

                    infoText()
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer()

                    ForEach(serverOperators) { srvOperator in
                        operatorCheckView(srvOperator)
                    }
                    VStack {
                        Text(NSLocalizedString("POPOPX Chat and Flux made an agreement to include Flux-operated servers into the app.", comment: "Server agreement")).padding(.bottom, 8)
                        Text(NSLocalizedString("You can configure servers via settings.", comment: "Server configuration hint"))
                    }
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(hex: "#C4BFD6"))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)

                    Spacer()

                    VStack(spacing: 8) {
                        setOperatorsButton()
                            .frame(maxWidth: .infinity)
                        onboardingButtonPlaceholder()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .sheet(item: $sheetItem) { item in
                switch item {
                case .showInfo:
                    ChooseServerOperatorsInfoView()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(25)
        .interactiveDismissDisabled(selectedOperatorIds.isEmpty)
    }

    private func infoText() -> some View {
        Button {
            sheetItem = .showInfo
        } label: {
            Label(NSLocalizedString("How it helps privacy", comment: "Privacy info label"), systemImage: "info.circle")
                .font(.headline)
                .foregroundColor(Color(hex: "#00FFD2"))
        }
    }

    private func operatorCheckView(_ serverOperator: ServerOperator) -> some View {
        let checked = selectedOperatorIds.contains(serverOperator.operatorId)
        let icon = checked ? "checkmark.circle.fill" : "circle"
        let iconColor = checked ? Color(hex: "#00FFD2") : Color(hex: "#C4BFD6")
        return HStack(spacing: 10) {
            Image(serverOperator.largeLogo(colorScheme))
                .resizable()
                .scaledToFit()
                .frame(height: 48)
            Spacer()
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundColor(iconColor)
        }
        .background(Color(hex: "#141021"))
        .padding()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: checked
                            ? [Color(hex: "#6E25C4").opacity(0.6), Color(hex: "#00FFD2").opacity(0.3)]
                            : [Color(hex: "#6E25C4").opacity(0.2), Color(hex: "#00FFD2").opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color(hex: "#6E25C4").opacity(checked ? 0.2 : 0.08), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 2)
        .onTapGesture {
            if checked {
                selectedOperatorIds.remove(serverOperator.operatorId)
            } else {
                selectedOperatorIds.insert(serverOperator.operatorId)
            }
        }
    }

    private func setOperatorsButton() -> some View {
        let noOperatorsAvailable = m.conditions.serverOperators.isEmpty
        return Button {
            dismiss()
        } label: {
            Text(NSLocalizedString("OK", comment: "OK button"))
        }
        .buttonStyle(QuantumButtonStyle(primary: true))
        .disabled(selectedOperatorIds.isEmpty && !noOperatorsAvailable)
    }
}

// Link to operator signup/registration page.
// Currently hardcoded; consider fetching from remote config to allow updates without app release.
let operatorsPostLink = URL(string: "https://popopxchat.com") ?? URL(filePath: "/")

struct ChooseServerOperatorsInfoView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var m: ChatModel

    var body: some View {
        NavigationStack {
            List {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("The app protects your privacy by using different operators in each conversation.", comment: "Privacy protection explanation"))
                    Text(NSLocalizedString("When more than one operator is enabled, none of them has metadata to learn who communicates with whom.", comment: "Multi-operator privacy"))
                    Text(NSLocalizedString("For example, if your contact receives messages via a POPOPX Chat server, your app will deliver them via a Flux server.", comment: "Operator example"))
                }
                .fixedSize(horizontal: false, vertical: true)
                        .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .padding(.top)

                Section {
                    ForEach(m.conditions.serverOperators) { op in
                        operatorInfoNavLinkView(op)
                    }
                } header: {
                    Text(NSLocalizedString("About operators", comment: "About operators section header"))
                        .foregroundColor(theme.colors.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .navigationTitle(NSLocalizedString("Server operators", comment: "Server operators navigation title"))
            .navigationBarTitleDisplayMode(.large)
            .modifier(ThemedBackground(grouped: true))
        }
    }

    private func operatorInfoNavLinkView(_ op: ServerOperator) -> some View {
        NavigationLink() {
            OperatorInfoView(serverOperator: op)
                .navigationTitle(NSLocalizedString("Network operator", comment: "Network operator title"))
                .modifier(ThemedBackground(grouped: true))
                .navigationBarTitleDisplayMode(.large)
        } label: {
            HStack {
                Image(op.logo(colorScheme))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(op.tradeName)
            }
        }
    }
}

#Preview {
    OnboardingConditionsView(initialOperatorIds: [])
        .previewEnvironment()
}
