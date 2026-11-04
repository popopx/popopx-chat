//
//  AuthenticationState.swift
//  POPOPX
//
//  Extracted from AppStateModel - Local authentication state
//

import Foundation
import Combine

@MainActor
final class AuthenticationState: ObservableObject {
    static let shared = AuthenticationState()

    @Published var contentViewAccessAuthenticated: Bool = false
    @Published var laRequest: LocalAuthRequest?

    func reset() {
        contentViewAccessAuthenticated = false
        laRequest = nil
    }
}
