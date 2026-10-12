//
//  CIInvalidJSONView.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 29.12.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// Spec: spec/client/chat-view.md#CIInvalidJSONView
struct CIInvalidJSONView: View {
    @EnvironmentObject var theme: AppTheme
    var json: Data?
    @State private var showJSON = false
    
    // POPOPX: layout constants for invalid JSON badge
    private let pxHorizPad: CGFloat = 14
    private let pxVertPad: CGFloat = 8
    private let pxErrorOpacity: Double = 0.90

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(NSLocalizedString("compose_invalid_data", comment: "Label for invalid JSON data"))
                .foregroundColor(theme.colors.error)
                .italic()
                .opacity(pxErrorOpacity)
        }
        .padding(.horizontal, pxHorizPad)
        .padding(.vertical, pxVertPad)
        .glassBackground()
        .textSelection(.disabled)
        .simultaneousGesture(TapGesture().onEnded { showJSON = true })
        .appSheet(isPresented: $showJSON) {
            invalidJSONView(dataToString(json))
        }
        .popopxBranded()
    }
}

func invalidJSONView(_ json: String) -> some View {
    VStack(alignment: .leading, spacing: 18) { // POPOPX: more vertical spacing
        Button { // this is used in the sheet, Button works here
            showShareSheet(items: [json])
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .opacity(0.85) // POPOPX: softer share icon
        ScrollView {
            Text(json)
        }
    }
    .frame(maxHeight: .infinity)
    .padding()
    .modifier(ThemedBackground())
}

struct CIInvalidJSONView_Previews: PreviewProvider {
    static var previews: some View {
        CIInvalidJSONView(json: "{}".data(using: .utf8) ?? Data()) // POPOPX: safe unwrap
    }
}

// MARK: - POPOPX
extension CIInvalidJSONView {
    var pxComponentTag: String { "PX_INVALID_JSON" }
}
