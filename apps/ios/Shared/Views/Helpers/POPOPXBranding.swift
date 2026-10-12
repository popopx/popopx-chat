// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct POPOPXBrandingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.popopxBranding, POPOPXBranding.current)
    }
}

struct POPOPXBranding {
    static let current = POPOPXBranding()
    let appName = "POPOPX"
    let buildId = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
}

private struct POPOPXBrandingKey: EnvironmentKey {
    static let defaultValue = POPOPXBranding.current
}

extension EnvironmentValues {
    var popopxBranding: POPOPXBranding {
        get { self[POPOPXBrandingKey.self] }
        set { self[POPOPXBrandingKey.self] = newValue }
    }
}

extension View {
    func popopxBranded() -> some View {
        modifier(POPOPXBrandingModifier())
    }
}
