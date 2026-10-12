// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import MessageUI
import POPOPXSwitch

struct SendAddressMailView: View {
    @Binding var showMailView: Bool
    @Binding var mailViewResult: Result<MFMailComposeResult, Error>?
    var userAddress: UserContactLink
    @State private var showMailUnavailableAlert = false

    var body: some View {
        let messageBody = String(format: NSLocalizedString("""
            <p>Hi!</p>
            <p><a href="%@">Connect to me via POPOPX Chat</a></p>
            """, comment: "email text"), popopxChatLink(userAddress.connLinkContact.popopxChatUri(short: false)))
        Group {
            if MFMailComposeViewController.canSendMail() {
                PXMailComposer(
                    isShowing: self.$showMailView,
                    result: $mailViewResult,
                    subject: NSLocalizedString("Let's talk in POPOPX Chat", comment: "email subject"),
                    messageBody: messageBody
                )
            } else {
                Color.clear
                    .onAppear {
                        showMailView = false
                        showMailUnavailableAlert = true
                    }
                    .alert(NSLocalizedString("Mail Not Configured", comment: "alert title"), isPresented: $showMailUnavailableAlert) {
                        Button(NSLocalizedString("ok_button", comment: "OK button"), role: .cancel) { }
                    } message: {
                        Text(LocalizedStringKey(NSLocalizedString("no_email_account_message", comment: "No email account alert message")))
                    }
            }
        }
        .popopxBranded()
    }
}
