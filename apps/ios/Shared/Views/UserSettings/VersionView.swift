//
//  VersionView.swift
//  POPOPXSwitch
//
//  Created by Evgeny on 22/01/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct VersionView: View {
    @State var versionInfo: CoreVersionInfo?

    var body: some View {
        VStack(alignment: .leading) {
            Text(String(format: NSLocalizedString("app_version_label", comment: "App version label"), appVersion ?? "?"))
                .font(isInDarkTheme() ? .subheadline : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
            Text(String(format: NSLocalizedString("app_build_label", comment: "App build label"), appBuild ?? "?"))
                .font(isInDarkTheme() ? .subheadline : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
            if let info = versionInfo {
                Text(String(format: NSLocalizedString("settings_core_version_fmt", comment: "Core library version label"), info.version))
                    .font(isInDarkTheme() ? .subheadline : .body)
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
                Text(String(format: NSLocalizedString("settings_core_engine_fmt", comment: "Core engine version label"), info.popopxmqVersion))
                    .font(isInDarkTheme() ? .subheadline : .body)
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .modifier(ThemedBackground(grouped: true))
        .onAppear {
            do {
                versionInfo = try apiGetVersion()
            } catch let error {
                logger.error("apiGetVersion error: \(responseError(error))")
            }
        }
        .popopxBranded()
    }
}

struct VersionView_Previews: PreviewProvider {
    static var previews: some View {
        VersionView()
    }
}
