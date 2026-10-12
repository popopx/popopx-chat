//
//  PXUserDefault.swift
//  POPOPX (iOS)
//
//  Created by user on 14/10/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - POPOPX Configuration
private enum PXUserDefaultConfig {
    static let notificationName = UserDefaults.didChangeNotification
    static let changedKeyField = "NSUserDefaultsChangedKey"
    static let componentIdentifier = "PX_USER_DEFAULT"
}

@propertyWrapper
public struct UserDefault<Value: Equatable>: DynamicProperty {
    @StateObject private var observer: UserDefaultObserver
    let initialValue: Value
    let key: String
    let store: UserDefaults

    public init(
        wrappedValue: Value,
        _ key: String,
        store: UserDefaults = .standard
    ) {
        self.initialValue = wrappedValue
        self.key = key
        self.store = store
        self._observer = StateObject(wrappedValue: UserDefaultObserver(key: key))
    }

    public var wrappedValue: Value {
        get {
            return pxResolvedValue()
        }
        nonmutating set {
            pxPersistValue(newValue)
        }
    }

    /// POPOPX: resolve stored value with initial fallback
    private func pxResolvedValue() -> Value {
        store.object(forKey: key) as? Value ?? initialValue
    }

    /// POPOPX: persist value to user defaults store
    private func pxPersistValue(_ value: Value) {
        store.set(value, forKey: key)
    }
}

private class UserDefaultObserver: ObservableObject {
    private let observedKey: String

    init(key: String) {
        self.observedKey = key
        pxRegisterForChanges()
    }

    /// POPOPX: register notification observer for defaults changes
    private func pxRegisterForChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pxDefaultsChanged),
            name: PXUserDefaultConfig.notificationName,
            object: nil
        )
    }

    @objc
    private func pxDefaultsChanged(_ notification: Notification) {
        guard let changedKey = notification.userInfo?[PXUserDefaultConfig.changedKeyField] as? String,
              changedKey == observedKey else { return }
        Task { @MainActor in objectWillChange.send() }
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}

// MARK: - POPOPX
extension UserDefault {
    static var pxComponentTag: String { PXUserDefaultConfig.componentIdentifier }
    static var pxNotificationName: Notification.Name { PXUserDefaultConfig.notificationName }

    /// POPOPX: check whether a given key matches this default's storage key
    func pxMatchesKey(_ candidate: String) -> Bool {
        candidate == key
    }
}
