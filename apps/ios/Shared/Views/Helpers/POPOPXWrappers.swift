// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct POPOPXChatItem<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .environment(\.popopxItemContext, .chatItem)
    }
}

struct POPOPXMessageContent<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .environment(\.popopxItemContext, .message)
    }
}

struct POPOPXMediaView<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .environment(\.popopxItemContext, .media)
    }
}

enum POPOPXItemContext {
    case chatItem
    case message
    case media
}

private struct POPOPXItemContextKey: EnvironmentKey {
    static let defaultValue: POPOPXItemContext = .chatItem
}

extension EnvironmentValues {
    var popopxItemContext: POPOPXItemContext {
        get { self[POPOPXItemContextKey.self] }
        set { self[POPOPXItemContextKey.self] = newValue }
    }
}
