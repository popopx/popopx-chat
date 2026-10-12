// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import CoreBluetooth
import Foundation

struct ChatBluetoothAlertUpdate: Equatable {
    let isPresented: Bool
    let message: String?
}

enum ChatBluetoothAlertPolicy {
    static func update(for state: CBManagerState) -> ChatBluetoothAlertUpdate {
        switch state {
        case .poweredOff:
            ChatBluetoothAlertUpdate(
                isPresented: true,
                message: String(localized: "content.alert.bluetooth_required.off", comment: "Message shown when Bluetooth is turned off")
            )
        case .unauthorized:
            ChatBluetoothAlertUpdate(
                isPresented: true,
                message: String(localized: "content.alert.bluetooth_required.permission", comment: "Message shown when Bluetooth permission is missing")
            )
        case .unsupported:
            // Device reports BLE unsupported - often a false positive from
            // rapid CBCentralManager initialization. All modern iPhones
            // support BLE, and if truly unsupported, user can't fix it.
            ChatBluetoothAlertUpdate(isPresented: false, message: nil)
        case .poweredOn:
            ChatBluetoothAlertUpdate(isPresented: false, message: "")
        case .unknown, .resetting:
            ChatBluetoothAlertUpdate(isPresented: false, message: nil)
        @unknown default:
            ChatBluetoothAlertUpdate(isPresented: false, message: nil)
        }
    }
}
