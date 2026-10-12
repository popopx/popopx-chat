//
//  MPVolumeView.swift
//  POPOPX (iOS)
//
//  Created by Avently on 24.04.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit
import AVKit

private enum PXAudioDevicePickerConfig {
    static let activeTint: UIColor = .white
    static let inactiveTint: UIColor = UIColor.white.withAlphaComponent(0.95)
    static let pickerFrame: CGRect = .zero
}

struct AudioDevicePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> some UIView {
        let v = AVRoutePickerView(frame: PXAudioDevicePickerConfig.pickerFrame)
        v.activeTintColor = PXAudioDevicePickerConfig.activeTint
        v.tintColor = PXAudioDevicePickerConfig.inactiveTint
        v.accessibilityLabel = NSLocalizedString("audio_device_picker_label", comment: "Audio device picker accessibility")
        return v
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {

    }
}

// MARK: - POPOPX
extension AudioDevicePicker {
    static let pxComponentTag: String = "px_audio_device_picker"
    static var pxRoutePickerViewType: String { "AVRoutePickerView" }
    static var pxIsAvailable: Bool { true }
}
