//
//  SendMessageView.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 29/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

private let liveMsgInterval: UInt64 = 3000_000000

// Spec: spec/client/compose.md#SendMessageView
struct SendMessageView: View {
    var placeholder: String?
    @Binding var composeState: ComposeState
    @Binding var selectedRange: NSRange
    @EnvironmentObject var theme: AppTheme
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.colorScheme) var colorScheme
    var sendMessage: (Int?) -> Void
    var sendLiveMessage: (() async -> Void)? = nil
    var updateLiveMessage: (() async -> Void)? = nil
    var cancelLiveMessage: (() -> Void)? = nil
    var sendToConnect: (() -> Void)? = nil
    var hideSendButton: Bool = false
    var showVoiceMessageButton: Bool = true
    var voiceMessageAllowed: Bool = true
    var disableSendButton = false
    var showEnableVoiceMessagesAlert: ChatInfo.ShowEnableVoiceMessagesAlert = .other
    var startVoiceMessageRecording: (() -> Void)? = nil
    var finishVoiceMessageRecording: (() -> Void)? = nil
    var allowVoiceMessagesToContact: (() -> Void)? = nil
    var timedMessageAllowed: Bool = false
    var onMediaAdded: ([UploadContent]) -> Void
    var attachmentButtons: (() -> AnyView)? = nil
    @State private var holdingVMR = false
    @Namespace var namespace
    @Binding var keyboardVisible: Bool
    @Binding var keyboardHiddenDate: Date
    var sendButtonColor = Color.accentColor
    @State private var teHeight: CGFloat = NativeTextEditor.minHeight
    @State private var teFont: Font = .body
    @State private var sendButtonSize: CGFloat = 29
    @State private var sendButtonOpacity: CGFloat = 1
    @State private var liveMessagePulseActive = false
    @State private var showCustomDisappearingMessageDialogue = false
    @State private var showCustomTimePicker = false
    @State private var selectedDisappearingMessageTime: Int? = customDisappearingMessageTimeDefault.get()
    @State private var pxPopScale: CGFloat = 1.0
    @UserDefault(DEFAULT_LIVE_MESSAGE_ALERT_SHOWN) private var liveMessageAlertShown = false
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Text input - height driven by teHeight binding from NativeTextEditor
            if case .voicePreview = composeState.preview {
                Text(NSLocalizedString("Voice message…", comment: ""))
                    .font(teFont.italic())
                    .multilineTextAlignment(.leading)
                    .foregroundColor(theme.colors.secondary)
                    .frame(height: NativeTextEditor.minHeight)
            } else {
                NativeTextEditor(
                    text: Binding(
                        get: { composeState.message },
                        set: { newValue in
                            if newValue.count <= 65536 {
                                DispatchQueue.main.async {
                                    composeState.message = newValue
                                }
                            }
                        }
                    ),
                    disableEditing: $composeState.inProgress,
                    height: $teHeight,
                    focused: $keyboardVisible,
                    lastUnfocusedDate: $keyboardHiddenDate,
                    placeholder: Binding(get: { placeholder ?? composeState.placeholder }, set: { _ in }),
                    selectedRange: $selectedRange,
                    onImagesAdded: onMediaAdded,
                    colorScheme: colorScheme
                )
                .allowsTightening(false)
                .fixedSize(horizontal: false, vertical: true)
            }

            // Row 2: All buttons in one row
            if !hideSendButton {
                HStack(spacing: 12) {
                    attachmentButtons?()
                    Spacer()
                    composeActionButtons()
                }
                .frame(minHeight: 44)
            }
        }
        .onChange(of: liveMessagePulseActive) { _, isActive in
            if !isActive {
                sendButtonSize = 29
                sendButtonOpacity = 1
            }
        }
        .task {
            while liveMessagePulseActive {
                let reduceMotion = UIAccessibility.isReduceMotionEnabled
                let pulseInterval: UInt64 = reduceMotion ? 2_000_000_000 : 1_500_000_000

                try? await Task.sleep(nanoseconds: pulseInterval)
                guard liveMessagePulseActive else { break }

                if reduceMotion {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        sendButtonOpacity = sendButtonOpacity == 1 ? 0.85 : 1
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        sendButtonSize = sendButtonSize == 29 ? 26 : 29
                        sendButtonOpacity = sendButtonOpacity == 1 ? 0.75 : 1
                    }
                }

                if composeState.liveMessage == nil {
                    liveMessagePulseActive = false
                    sendButtonSize = 29
                    sendButtonOpacity = 1
                }
            }
        }
        .onChange(of: composeState.message) { _, text in updateFont(text) }
        .overlay {
            if keyboardVisible {
                TimelineView(.animation(minimumInterval: 1.0 / 2.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { timeline in // POPOPX: 2fps, was 12fps
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    let angle = Angle.degrees(phase.truncatingRemainder(dividingBy: 3.0) / 3.0 * 360.0)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            AngularGradient(
                                colors: [Color(hex: "#6E25C4"), Color(hex: "#00FFD2"), Color(hex: "#FF00A0"), Color(hex: "#6E25C4")],
                                center: .center,
                                angle: angle
                            ).opacity(0.5),
                            lineWidth: 1.2
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .popopxBranded()
    }

    private var warningColor: Color {
        let charCount = composeState.message.count
        if charCount > 64000 {
            return theme.colors.error  // Red at 98% (64k/65536)
        } else if charCount > 55000 {
            return QuantumColors.warning  // Orange at 84% (55k/65536)
        } else if charCount > 40000 {
            return .secondary  // Secondary at 61% (40k/65536)
        }
        return .clear
    }

    @ViewBuilder private func charCountWarningView() -> some View {
        let charCount = composeState.message.count
        if charCount > 40000 {
            Text(String(format: NSLocalizedString("compose_char_count_format", comment: "Character count warning format"), charCount))
                .font(.caption2)
                .foregroundColor(warningColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 4)
                .padding(.trailing, 8)
                .transition(.opacity)
        }
    }

    @ViewBuilder private func composeActionButtons() -> some View {
        let vmrs = composeState.voiceMessageRecordingState
        if hideSendButton {
            EmptyView()
        } else if let connect = sendToConnect {
            sendToConnectButton(connect)
        } else if case .reportedItem = composeState.contextItem {
            sendMessageButton()
        } else if showVoiceMessageButton
            && composeState.message.isEmpty
            && !composeState.editing
            && !composeState.forwarding
            && composeState.liveMessage == nil
            && ((composeState.noPreview && vmrs == .noRecording)
                || (vmrs == .recording && holdingVMR)) {
            HStack {
                if voiceMessageAllowed {
                    RecordVoiceMessageButton(
                        startVoiceMessageRecording: startVoiceMessageRecording,
                        finishVoiceMessageRecording: finishVoiceMessageRecording,
                        holdingVMR: $holdingVMR,
                        disabled: composeState.inProgress
                    )
                } else {
                    voiceMessageNotAllowedButton()
                }
                if let send = sendLiveMessage,
                   let update = updateLiveMessage,
                   case .noContextItem = composeState.contextItem {
                    startLiveMessageButton(send: send, update: update)
                }
            }
        } else if vmrs == .recording && !holdingVMR {
            finishVoiceMessageRecordingButton()
        } else if composeState.liveMessage != nil && composeState.liveMessage?.sentMsg == nil && composeState.message.isEmpty {
            cancelLiveMessageButton {
                cancelLiveMessage?()
            }
        } else {
            sendMessageButton()
        }
    }

    private func deleteTextButton() -> some View {
        Button {
            composeState.message = ""
        } label: {
            Image(systemName: "multiply.circle.fill")
        }
        .foregroundColor(Color(uiColor: .tertiaryLabel))
        .padding([.top, .trailing], 4)
    }

    private func sendToConnectButton(_ connect: @escaping () -> Void) -> some View {
        let disabled = !composeState.sendEnabled || composeState.inProgress || disableSendButton
        return Button(action: connect) {
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .foregroundColor(disabled ? theme.colors.secondary.opacity(0.67) : sendButtonColor)
                .frame(width: sendButtonSize, height: sendButtonSize)
                .opacity(sendButtonOpacity)
        }
        .disabled(disabled)
        .frame(width: 31, height: 31)
        .padding([.bottom, .trailing], 4)
    }

    private func sendMessageButton() -> some View {
        Button {
            if composeState.editing || composeState.liveMessage != nil {
                sendMessage(nil)
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    pxPopScale = 1.4
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        pxPopScale = 1.0
                    }
                }
                sendMessage(nil)
            }
        } label: {
            if composeState.editing || composeState.liveMessage != nil {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(sendButtonColor))
                    .opacity(composeState.message.isEmpty ? 0.4 : 1)
            } else {
                pxMiniBalloon3D
                    .frame(width: 28, height: 28)
                    .scaleEffect(pxPopScale)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color(hex: "#6E25C4").opacity(0.6), radius: 8)
                    .opacity(composeState.message.isEmpty ? 0.4 : 1)
            }
        }
        .disabled(
            !composeState.sendEnabled ||
            composeState.inProgress ||
            (!voiceMessageAllowed && composeState.voicePreview) ||
            composeState.endLiveDisabled ||
            disableSendButton
        )
        .contextMenu{
            sendButtonContextMenuItems()
        }
        .confirmationDialog(NSLocalizedString("Send disappearing message", comment: "confirmation dialog title"), isPresented: $showCustomDisappearingMessageDialogue, titleVisibility: .visible) {
            Button(NSLocalizedString("30 seconds", comment: "")) { sendMessage(30) }
            Button(NSLocalizedString("1 minute", comment: "")) { sendMessage(60) }
            Button(NSLocalizedString("5 minutes", comment: "")) { sendMessage(300) }
            Button(NSLocalizedString("Custom time", comment: "")) { showCustomTimePicker = true }
        }
        .sheet(isPresented: $showCustomTimePicker, onDismiss: { selectedDisappearingMessageTime = customDisappearingMessageTimeDefault.get() }) {
            disappearingMessageCustomTimePicker()
                .presentationDetents([.medium])
        }
    }

    private var pxMiniBalloon3D: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#A855F7"), Color(hex: "#6E25C4"), Color(hex: "#4A1A8A")],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 1,
                        endRadius: 14
                    )
                )

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.35), .clear],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 7
                    )
                )
                .frame(width: 10, height: 7)
                .offset(x: -3, y: -4)

            Circle()
                .fill(Color(hex: "#6E25C4"))
                .frame(width: 3, height: 3)
                .offset(y: 12)
        }
    }

    private func disappearingMessageCustomTimePicker() -> some View {
        PXTimePickerView(
            selection: $selectedDisappearingMessageTime,
            confirmButtonText: "Send",
            confirmButtonAction: {
                if let time = selectedDisappearingMessageTime {
                    sendMessage(time)
                    customDisappearingMessageTimeDefault.set(time)
                }
            },
            description: LocalizedStringKey(NSLocalizedString("prefs_delete_after", comment: "Delete after"))
        )
    }

    @ViewBuilder private func sendButtonContextMenuItems() -> some View {
        if composeState.liveMessage == nil,
           !composeState.editing {
            if case .noContextItem = composeState.contextItem,
               !composeState.voicePreview,
               !composeState.manyMediaPreviews,
               let send = sendLiveMessage,
               let update = updateLiveMessage {
                Button {
                    startLiveMessage(send: send, update: update)
                } label: {
                    Label(NSLocalizedString("compose_send_live_message", comment: "Send live message button"), systemImage: "bolt.fill")
                }
            }
            if timedMessageAllowed {
                Button {
                    hideKeyboard()
                    showCustomDisappearingMessageDialogue = true
                } label: {
                    Label(NSLocalizedString("compose_disappearing_message", comment: "Disappearing message button"), systemImage: "stopwatch")
                }
            }
        }
    }

    private struct RecordVoiceMessageButton: View {
        @Environment(\.isEnabled) var isEnabled
        @EnvironmentObject var theme: AppTheme
        var startVoiceMessageRecording: (() -> Void)?
        var finishVoiceMessageRecording: (() -> Void)?
        @Binding var holdingVMR: Bool
        var disabled: Bool
        @State private var pressed: TimeInterval? = nil

        var body: some View {
            Image(systemName: isEnabled ? "mic.fill" : "mic")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isEnabled ? theme.colors.primary : theme.colors.secondary)
                .opacity(holdingVMR ? 0.7 : 1)
                .disabled(disabled)
                .accessibilityLabel(Text(NSLocalizedString("Record voice message", comment: "")))
                .frame(width: 36, height: 36)
                .padding([.bottom, .trailing], 4)
                ._onButtonGesture { down in
                    if down {
                        holdingVMR = true
                        pressed = ProcessInfo.processInfo.systemUptime
                        startVoiceMessageRecording?()
                    } else {
                        if let pressed, ProcessInfo.processInfo.systemUptime - pressed >= 1 {
                            finishVoiceMessageRecording?()
                        }
                        holdingVMR = false
                        pressed = nil
                    }
                } perform: {}
        }
    }

    private func voiceMessageNotAllowedButton() -> some View {
        Button {
            switch showEnableVoiceMessagesAlert {
            case .userEnable:
                AlertManager.shared.showAlert(Alert(
                    title: Text(LocalizedStringKey(NSLocalizedString("voice_allow_title", comment: ""))),
                    message: Text(LocalizedStringKey(NSLocalizedString("voice_allow_message", comment: ""))),
                    primaryButton: .default(Text(LocalizedStringKey("Allow"))) {
                        allowVoiceMessagesToContact?()
                    },
                    secondaryButton: .cancel()
                ))
            case .askContact:
                AlertManager.shared.showAlertMsg(
                    title: LocalizedStringKey(NSLocalizedString("voice_messages_prohibited_title", comment: "Voice messages prohibited alert title")),
                    message: LocalizedStringKey(NSLocalizedString("voice_messages_prohibited_ask_contact_message", comment: "Voice messages prohibited ask contact message"))
                )
            case .groupOwnerCan:
                AlertManager.shared.showAlertMsg(
                    title: LocalizedStringKey(NSLocalizedString("voice_messages_prohibited_title", comment: "Voice messages prohibited alert title")),
                    message: LocalizedStringKey(NSLocalizedString("voice_messages_prohibited_group_owner_message", comment: "Voice messages prohibited group owner message"))
                )
            case .other:
                AlertManager.shared.showAlertMsg(
                    title: LocalizedStringKey(NSLocalizedString("voice_messages_prohibited_title", comment: "Voice messages prohibited alert title")),
                    message: LocalizedStringKey(NSLocalizedString("voice_messages_prohibited_other_message", comment: "Voice messages prohibited other message"))
                )
            }
        } label: {
            Image(systemName: "mic")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(theme.colors.secondary)
        }
        .disabled(composeState.inProgress)
        .frame(width: 31, height: 31)
        .padding([.bottom, .trailing], 4)
    }

    private func cancelLiveMessageButton(cancel: @escaping () -> Void) -> some View {
        return Button {
            cancel()
        } label: {
            Image(systemName: "multiply")
                .resizable()
                .scaledToFit()
                .foregroundColor(theme.colors.primary)
                .frame(width: 15, height: 15)
        }
        .accessibilityLabel(Text(NSLocalizedString("Cancel", comment: "")))
        .frame(width: 44, height: 44)
        .padding([.bottom, .horizontal], 4)
    }

    private func startLiveMessageButton(send:  @escaping () async -> Void, update: @escaping () async -> Void) -> some View {
        return Button {
            switch composeState.preview {
            case .noPreview: startLiveMessage(send: send, update: update)
            default: ()
            }
        } label: {
            Image(systemName: "bolt.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(isEnabled ? theme.colors.primary : theme.colors.secondary)
                .frame(width: 20, height: 20)
        }
        .accessibilityLabel(Text(NSLocalizedString("Send live message", comment: "")))
        .frame(width: 44, height: 44)
        .padding([.bottom, .horizontal], 4)
    }

    private func startLiveMessage(send:  @escaping () async -> Void, update: @escaping () async -> Void) {
        if liveMessageAlertShown {
            start()
        } else {
            AlertManager.shared.showAlert(Alert(
                title: Text(LocalizedStringKey(NSLocalizedString("live_message_title", comment: ""))),
                message: Text(LocalizedStringKey(NSLocalizedString("live_message_description", comment: ""))),
                primaryButton: .default(Text(LocalizedStringKey("Send"))) {
                    liveMessageAlertShown = true
                    start()
                },
                secondaryButton: .cancel()
            ))
        }

        func start() {
            Task {
                await send()
                await MainActor.run { run() }
            }
        }

        func run() {
            liveMessagePulseActive = true
            Task {
                _ = try? await Task.sleep(nanoseconds: liveMsgInterval)
                while composeState.liveMessage != nil {
                    await update()
                    _ = try? await Task.sleep(nanoseconds: liveMsgInterval)
                }
            }
        }
    }

    private func finishVoiceMessageRecordingButton() -> some View {
        Button(action: { finishVoiceMessageRecording?() }) {
            Image(systemName: "stop.fill")
                .foregroundColor(theme.colors.primary)
        }
        .disabled(composeState.inProgress)
        .frame(width: 31, height: 31)
        .padding([.bottom, .trailing], 4)
    }

    private func updateFont(_ text: String) {
        teFont = isShortEmoji(text)
        ? (text.count < 4 ? largeEmojiFont : mediumEmojiFont)
        : .body
    }
}

struct SendMessageView_Previews: PreviewProvider {
    static var previews: some View {
        @State var composeStateNew = ComposeState()
        @State var selectedRange = NSRange()
        let ci = ChatItem.getSample(1, .directSnd, .now, "hello")
        @State var composeStateEditing = ComposeState(editingItem: ci)
        @State var selectedRangeEditing = NSRange()
        @State var sendEnabled: Bool = true

        return Group {
            VStack {
                Text(LocalizedStringKey(""))
                Spacer(minLength: 0)
                SendMessageView(
                    composeState: $composeStateNew,
                    selectedRange: $selectedRange,
                    sendMessage: { _ in },
                    onMediaAdded: { _ in },
                    keyboardVisible: Binding.constant(true),
                    keyboardHiddenDate: Binding.constant(Date.now)
                )
            }
            VStack {
                Text(LocalizedStringKey(""))
                Spacer(minLength: 0)
                SendMessageView(
                    composeState: $composeStateEditing,
                    selectedRange: $selectedRangeEditing,
                    sendMessage: { _ in },
                    onMediaAdded: { _ in },
                    keyboardVisible: Binding.constant(true),
                    keyboardHiddenDate: Binding.constant(Date.now)
                )
            }
        }
        .previewEnvironment()
    }
}
