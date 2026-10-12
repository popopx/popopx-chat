// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

/// Public entry point for embedding bitchat UI in a host app (e.g. POPOPX).
/// This view bootstraps the AppRuntime and injects all required environment objects.
public struct BitchatBridgeView: View {
    @StateObject private var runtime: AppRuntime

    public init() {
        _runtime = StateObject(wrappedValue: BitchatSharedRuntime.shared.runtime())
    }

    public var body: some View {
        ContentView()
            .environment(\.appTheme, .matrix)
            .environmentObject(runtime.publicChatModel)
            .environmentObject(runtime.privateInboxModel)
            .environmentObject(runtime.privateConversationModel)
            .environmentObject(runtime.verificationModel)
            .environmentObject(runtime.conversationUIModel)
            .environmentObject(runtime.locationChannelsModel)
            .environmentObject(runtime.peerListModel)
            .environmentObject(runtime.appChromeModel)
            .environmentObject(runtime.boardAlertsModel)
            .environmentObject(runtime.sharedContentImportModel)
            .onAppear {
                BitchatSharedRuntime.shared.register(runtime)
                runtime.start()
            }
    }
}
