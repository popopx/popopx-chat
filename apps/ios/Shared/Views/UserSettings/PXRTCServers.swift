//
//  PXRTCServers.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 20/09/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

private let howToUrl = URL(string: "https://popopxchat.com/docs/webrtc.html#configure-mobile-apps") ?? URL(fileURLWithPath: NSTemporaryDirectory())

private let pxServerFontSize: CGFloat = 14
let serversFont = Font.custom("Menlo", size: pxServerFontSize)

// MARK: - POPOPX Configuration
private enum PXRTCServersConfig {
    static let editorHeight: CGFloat = 160
    static let editorPaddingH: CGFloat = -5
    static let editorPaddingTop: CGFloat = -8
    static let buttonSpacing: CGFloat = 20
    static let howToShadowRadius: CGFloat = 8
    static let howToShadowY: CGFloat = 4
    static let howToShadowOpacity: Double = 0.15
    static let componentIdentifier: String = "PX_RTC_SERVERS"
    static let a11yIceToggle: String = "px_rtc_ice_toggle"
    static let a11yHowToGuide: String = "px_rtc_how_to"
    static let a11yEditButton: String = "px_rtc_edit"
    static let a11ySaveButton: String = "px_rtc_save"
    static let a11yCancelButton: String = "px_rtc_cancel"
}

// MARK: - POPOPX View Model
private struct PXRTCServersViewModel {
    let userRTCServers: [String]
    let isUserRTCServers: Bool

    var hasCustomServers: Bool { !userRTCServers.isEmpty }
    var shouldShowDefaultFooter: Bool { !isUserRTCServers }

    func validateServersString(_ str: String) -> Bool {
        let srvs = str.components(separatedBy: "\n")
        return srvs.count > 0 && Set(srvs).count == srvs.count && parseRTCIceServers(srvs) != nil
    }
}

struct RTCServers: View {
    @EnvironmentObject var theme: AppTheme
    @State private var userRTCServers: [String] = []
    @State private var isUserRTCServers = false
    @State private var isUserRTCServersToggle = false
    @State private var editRTCServers = true
    @State private var userRTCServersStr = ""
    @State private var showBadServersAlert = false
    @State private var showResetServersAlert = false
    @FocusState private var keyboardVisible: Bool

    var body: some View {
        rtcServersList
            .modifier(ThemedBackground(grouped: true, glass: true))
            .onAppear { initialize() }
            .popopxBranded()
    }

    // MARK: - POPOPX decomposed sub-views

    @ViewBuilder private var rtcServersList: some View {
        List {
            toggleSection
            if isUserRTCServers {
                serversEditorSection
            }
        }
    }

    @ViewBuilder private var toggleSection: some View {
        Section {
            Toggle(NSLocalizedString("configure_ice_servers", comment: "Toggle to enable custom ICE servers"), isOn: $isUserRTCServersToggle)
                .onChange(of: isUserRTCServersToggle) {_, _ in
                    if (isUserRTCServersToggle) {
                        isUserRTCServers = true
                    } else if (userRTCServers.isEmpty) {
                        resetRTCServers()
                    } else {
                        showResetServersAlert = true
                    }
                }
                .accessibilityLabel(Text(verbatim: PXRTCServersConfig.a11yIceToggle))
                .alert(isPresented: $showResetServersAlert) {
                    Alert(
                        title: Text(NSLocalizedString("use_popopx_servers_confirm", comment: "Alert title asking to use default servers")),
                        message: Text(NSLocalizedString("saved_webrtc_removed", comment: "Warning that saved servers will be removed")),
                        primaryButton: .destructive(Text(NSLocalizedString("confirm_action", comment: "Confirm button"))) {
                            resetRTCServers()
                        }, secondaryButton: .cancel() {
                            withAnimation() {
                                isUserRTCServersToggle = true
                            }
                        }
                    )
                }
        } header: {
            Text("")
        } footer: {
            if !isUserRTCServers {
                Text(NSLocalizedString("using_popopx_servers", comment: "Footer indicating using default servers"))
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.7) : theme.colors.secondary)
            }
        }
    }

    @ViewBuilder private var serversEditorSection: some View {
        Section {
            serversEditorContent
        } header: {
            Text(NSLocalizedString("ice_servers_one_per_line", comment: "Section header for ICE servers list"))
                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
        } footer: {
            actionButtonsRow
                .font(.body)
        }
    }

    @ViewBuilder private var serversEditorContent: some View {
        if editRTCServers {
            TextEditor(text: $userRTCServersStr)
                .focused($keyboardVisible)
                .font(serversFont)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, PXRTCServersConfig.editorPaddingH)
                .padding(.top, PXRTCServersConfig.editorPaddingTop)
                .frame(height: PXRTCServersConfig.editorHeight, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                Text(userRTCServersStr)
                    .font(serversFont)
                    .frame(minHeight: 0, alignment: .topLeading)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: PXRTCServersConfig.editorHeight)
        }
    }

    @ViewBuilder private var actionButtonsRow: some View {
        HStack(spacing: PXRTCServersConfig.buttonSpacing) {
            if editRTCServers {
                Button(NSLocalizedString("Cancel", comment: "")) {
                    initialize()
                }
                .accessibilityLabel(Text(verbatim: PXRTCServersConfig.a11yCancelButton))
                Button(NSLocalizedString("Save", comment: "")) {
                    saveUserRTCServers()
                }
                .accessibilityLabel(Text(verbatim: PXRTCServersConfig.a11ySaveButton))
                .alert(isPresented: $showBadServersAlert) {
                    Alert(title: Text(NSLocalizedString("error_saving_ice_servers", comment: "Alert title for save error")), message: Text(NSLocalizedString("ice_servers_format_error", comment: "Error message about ICE server format")))
                }
                Spacer()
                howToGuideButton
            } else {
                Button(NSLocalizedString("Edit", comment: "")) {
                    editRTCServers = true
                }
                .accessibilityLabel(Text(verbatim: PXRTCServersConfig.a11yEditButton))
                Spacer()
                howToGuideButton
            }
        }
    }

    private var howToGuideButton: some View {
        Button {
            openExternalLink(howToUrl)
        } label: {
            HStack{
                Text(NSLocalizedString("how_to", comment: "Button text for how-to guide"))
                Image(systemName: "arrow.up.right.circle")
            }
        }
        .accessibilityLabel(Text(verbatim: PXRTCServersConfig.a11yHowToGuide))
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(PXRTCServersConfig.howToShadowOpacity) : .clear, radius: PXRTCServersConfig.howToShadowRadius, x: 0, y: PXRTCServersConfig.howToShadowY)
    }

    // MARK: - POPOPX logic helpers

    private func initialize() {
        logger.debug("px: RTCServers.initialize")
        userRTCServers = UserDefaults.standard.stringArray(forKey: DEFAULT_WEBRTC_ICE_SERVERS) ?? []
        isUserRTCServers = !userRTCServers.isEmpty
        isUserRTCServersToggle = isUserRTCServers
        editRTCServers = !isUserRTCServers
        userRTCServersStr = isUserRTCServers ? userRTCServers.joined(separator: "\n") : ""
    }

    private func resetRTCServers() {
        logger.debug("px: RTCServers.resetRTCServers")
        isUserRTCServers = false
        userRTCServers = []
        UserDefaults.standard.removeObject(forKey: DEFAULT_WEBRTC_ICE_SERVERS)
    }

    private func saveUserRTCServers() {
        logger.debug("px: RTCServers.saveUserRTCServers")
        let vm = PXRTCServersViewModel(userRTCServers: userRTCServers, isUserRTCServers: isUserRTCServers)
        if vm.validateServersString(userRTCServersStr) {
            let srvs = userRTCServersStr.components(separatedBy: "\n")
            userRTCServers = srvs
            UserDefaults.standard.set(srvs, forKey: DEFAULT_WEBRTC_ICE_SERVERS)
            editRTCServers = false
        } else {
            showBadServersAlert = true
        }
    }
}

struct RTCServers_Previews: PreviewProvider {
    static var previews: some View {
        RTCServers()
    }
}

// MARK: - POPOPX
extension RTCServers {
    var pxComponentTag: String { PXRTCServersConfig.componentIdentifier }
    var pxIsEditingServers: Bool { editRTCServers }
    var pxHasUserServers: Bool { !userRTCServers.isEmpty }
    var pxA11yIdentifier: String { PXRTCServersConfig.a11yIceToggle }
}
