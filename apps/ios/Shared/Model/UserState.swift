//
//  UserState.swift
//  POPOPX
//
//  Extracted from ChatModel.swift - User-related state
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import Combine
import SwiftUI
@preconcurrency import POPOPXSwitch

/// Manages current user, user list, and user address
@MainActor
final class UserState: ObservableObject {
    @Published var currentUser: User? {
        didSet {
            Task { @MainActor in ThemeManager.applyTheme(currentThemeDefault.get()) }
        }
    }
    @Published var users: [UserInfo] = []
    @Published var userAddress: UserContactLink?

    static let shared = UserState()

    // MARK: - User Access

    func getUser(_ userId: Int64) -> User? {
        currentUser?.userId == userId
        ? currentUser
        : users.first { $0.user.userId == userId }?.user
    }

    func getUserIndex(_ user: User) -> Int? {
        users.firstIndex { $0.user.userId == user.userId }
    }

    // MARK: - User Management

    func updateUser(_ user: User) {
        if let i = getUserIndex(user) {
            users[i].user = user
        }
        if currentUser?.userId == user.userId {
            currentUser = user
        }
    }

    func removeUser(_ user: User) {
        if let i = getUserIndex(user) {
            users.remove(at: i)
        }
    }

    // MARK: - Address

    var addressShortLinkDataSet: Bool {
        userAddress?.shortLinkDataSet ?? true
    }

    // MARK: - Reset

    func reset() {
        currentUser = nil
        users = []
        userAddress = nil
    }
}
