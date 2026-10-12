//
//  IncomingCallView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 24/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Visual Configuration
private enum PxCallVisual {
    static let cornerRadius: CGFloat = 16
    static let borderWidth: CGFloat = 0.75
    static let iconScale: CGFloat = 1.24
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
    static let buttonIconSize: CGFloat = 24
    static let buttonMinWidth: CGFloat = 44
    static let buttonIconSpacing: CGFloat = 2
    static let shadowRadius: CGFloat = 12
    static let shadowYOffset: CGFloat = 4
    static let shadowOpacityDark: Double = 0.1
    static let iconShadowRadius: CGFloat = 6
    static let iconShadowOpacity: Double = 0.4
    static let profileAvatarSize: CGFloat = 24
    static let profileVerticalPadding: CGFloat = 6
    static let stackSpacing: CGFloat = 6
}

// MARK: - POPOPX Color Configuration
private enum PxCallColors {
    static let darkGradientTop = Color(red: 0.055, green: 0.055, blue: 0.102)
    static let darkGradientBottom = Color(red: 0.086, green: 0.086, blue: 0.165)
    static let darkGradientTopOpacity: Double = 0.9
    static let darkGradientBottomOpacity: Double = 0.8
    static let darkBorderPrimaryOpacity: Double = 0.3
    static let darkBorderSecondaryOpacity: Double = 0.15
    static let lightBorderPrimaryOpacity: Double = 0.4
    static let lightBorderSecondaryOpacity: Double = 0.1
}

// MARK: - POPOPX Call Action Model
private struct PxCallAction {
    let pxLabel: LocalizedStringKey
    let pxIcon: String
    let pxTint: Color
    let pxHandler: () -> Void
}

struct IncomingCallView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var cc = CallController.shared

    private var pxSoundPlayer: SoundPlayer { SoundPlayer.shared }

    var body: some View {
        Group {
            if let invitation = cc.activeCallInvitation {
                pxCallContent(invitation)
            }
        }
        .popopxBranded()
    }

    // MARK: - POPOPX Call Content

    @ViewBuilder
    private func pxCallContent(_ invitation: RcvCallInvitation) -> some View {
        if m.showCallView {
            pxIncomingPanel(invitation)
        } else {
            pxIncomingPanel(invitation)
                .onAppear { pxSoundPlayer.startRingtone() }
                .onDisappear { pxSoundPlayer.stopRingtone() }
        }
    }

    @ViewBuilder
    private func pxIncomingPanel(_ invitation: RcvCallInvitation) -> some View {
        VStack(alignment: .leading, spacing: PxCallVisual.stackSpacing) {
            pxCallerInfoRow(invitation)
            pxActionButtonsRow(invitation)
        }
        .padding(.horizontal, PxCallVisual.horizontalPadding)
        .padding(.vertical, PxCallVisual.verticalPadding)
        .frame(maxWidth: .infinity)
        .background(pxPanelBackground)
        .overlay(pxPanelBorder)
        .clipShape(RoundedRectangle(cornerRadius: PxCallVisual.cornerRadius, style: .continuous))
        .shadow(color: pxPanelShadowColor, radius: PxCallVisual.shadowRadius, x: 0, y: PxCallVisual.shadowYOffset)
        .onAppear { dismissAllSheets() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(NSLocalizedString("Incoming call", comment: "Incoming call accessibility label")))
    }

    // MARK: - POPOPX Sub-views

    @ViewBuilder
    private func pxCallerInfoRow(_ invitation: RcvCallInvitation) -> some View {
        HStack {
            if m.users.count > 1 {
                ProfileImage(imageStr: invitation.user.image, size: PxCallVisual.profileAvatarSize, color: .white)
            }
            Image(systemName: invitation.callType.media == .video ? "video.fill" : "phone.fill")
                .foregroundColor(QuantumColors.success)
            Text(invitation.callTypeText)
        }
    }

    @ViewBuilder
    private func pxActionButtonsRow(_ invitation: RcvCallInvitation) -> some View {
        HStack {
            ProfilePreview(profileOf: invitation.contact, color: .white)
                .padding(.vertical, PxCallVisual.profileVerticalPadding)
            Spacer()
            pxActionButton(pxRejectAction(invitation))
            pxActionButton(pxIgnoreAction())
            pxActionButton(pxAcceptAction(invitation))
        }
    }

    // MARK: - POPOPX Action Definitions

    private func pxRejectAction(_ invitation: RcvCallInvitation) -> PxCallAction {
        PxCallAction(
            pxLabel: LocalizedStringKey(NSLocalizedString("Reject", comment: "")),
            pxIcon: "phone.down.fill",
            pxTint: QuantumColors.error,
            pxHandler: { cc.endCall(invitation: invitation) }
        )
    }

    private func pxIgnoreAction() -> PxCallAction {
        PxCallAction(
            pxLabel: LocalizedStringKey(NSLocalizedString("Ignore", comment: "")),
            pxIcon: "multiply",
            pxTint: .primary,
            pxHandler: { cc.activeCallInvitation = nil }
        )
    }

    private func pxAcceptAction(_ invitation: RcvCallInvitation) -> PxCallAction {
        PxCallAction(
            pxLabel: LocalizedStringKey(NSLocalizedString("Accept", comment: "")),
            pxIcon: "checkmark",
            pxTint: QuantumColors.success,
            pxHandler: {
                if let call = m.activeCall {
                    cc.endCall(call: call) {
                        DispatchQueue.main.async {
                            cc.answerCall(invitation: invitation)
                        }
                    }
                } else {
                    cc.answerCall(invitation: invitation)
                }
            }
        )
    }

    // MARK: - POPOPX Button Builder

    @ViewBuilder
    private func pxActionButton(_ action: PxCallAction) -> some View {
        Button(action: action.pxHandler, label: {
            VStack(spacing: PxCallVisual.buttonIconSpacing) {
                Image(systemName: action.pxIcon)
                    .scaleEffect(PxCallVisual.iconScale)
                    .foregroundColor(action.pxTint)
                    .frame(width: PxCallVisual.buttonIconSize, height: PxCallVisual.buttonIconSize)
                    .shadow(color: isInDarkTheme() ? action.pxTint.opacity(PxCallVisual.iconShadowOpacity) : .clear, radius: PxCallVisual.iconShadowRadius, x: 0, y: 2)
                Text(action.pxLabel)
                    .font(.caption.weight(.medium))
                    .foregroundColor(theme.colors.secondary)
            }
            .frame(minWidth: PxCallVisual.buttonMinWidth)
        })
        .accessibilityLabel(Text(action.pxLabel))
    }

    // MARK: - POPOPX Background & Border

    @ViewBuilder
    private var pxPanelBackground: some View {
        ZStack {
            Color.clear.overlay(.ultraThinMaterial)
            if isInDarkTheme() {
                LinearGradient(
                    colors: [
                        PxCallColors.darkGradientTop.opacity(PxCallColors.darkGradientTopOpacity),
                        PxCallColors.darkGradientBottom.opacity(PxCallColors.darkGradientBottomOpacity)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private var pxPanelBorder: some View {
        RoundedRectangle(cornerRadius: PxCallVisual.cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: pxBorderColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: PxCallVisual.borderWidth
            )
    }

    private var pxBorderColors: [Color] {
        if isInDarkTheme() {
            return [darkThemeAccentColor().opacity(PxCallColors.darkBorderPrimaryOpacity), neonGradientSecondary().opacity(PxCallColors.darkBorderSecondaryOpacity)]
        }
        return [Color.white.opacity(PxCallColors.lightBorderPrimaryOpacity), Color.white.opacity(PxCallColors.lightBorderSecondaryOpacity)]
    }

    private var pxPanelShadowColor: Color {
        isInDarkTheme() ? darkThemeAccentColor().opacity(PxCallVisual.shadowOpacityDark) : .clear
    }
}

// MARK: - POPOPX Previews

struct IncomingCallView_Previews: PreviewProvider {
    static var previews: some View {
        CallController.shared.activeCallInvitation = RcvCallInvitation.sampleData
        let m = ChatModel()
        m.users = [UserInfo.sampleData, UserInfo.sampleData]
        return IncomingCallView().environmentObject(m)
    }
}

// MARK: - POPOPX Component Metadata
extension IncomingCallView {
    static let pxComponentTag: String = "PX_INCOMING_CALL_VIEW"
    static var pxCallViewVisible: Bool { CallController.shared.activeCallInvitation != nil }
    static var pxBrandingLabel: String { "IncomingCallView-PX" }
}
