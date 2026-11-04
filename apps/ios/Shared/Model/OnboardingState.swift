//
//  OnboardingState.swift
//  POPOPX
//
//  Extracted from AppStateModel - Onboarding and migration state
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class OnboardingState: ObservableObject {
    static let shared = OnboardingState()

    @Published var onboardingStage: OnboardingStage?
    @Published var migrationState: MigrationToState? = MigrationToDeviceState.makeMigrationState()

    func reset() {
        onboardingStage = nil
        migrationState = MigrationToDeviceState.makeMigrationState()
    }
}
