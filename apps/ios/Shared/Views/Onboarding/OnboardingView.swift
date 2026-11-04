//
//  OnboardingStepsView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 07/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/navigation.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// Spec: spec/client/navigation.md#OnboardingView
struct OnboardingView: View {
    @EnvironmentObject var chatModel: ChatModel
    @ObservedObject var appState = AppStateModel.shared
    var onboarding: OnboardingStage

    var body: some View {
        let currentStage = appState.onboardingStage ?? onboarding

        NavigationStack {
            Group {
                switch currentStage {
                case .step1_WelcomeIdentity:
                    OnboardingWelcomeIdentityView()
                        .background(QuantumColors.background.ignoresSafeArea())
                case .step2_CreateProfile:
                    CreateFirstProfile()
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                case .step3_PrivacyChoice:
                    PrivacyChoiceView()
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                case .step4_GetStarted:
                    GetStartedView()
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                case .onboardingComplete:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(NSLocalizedString("Loading...", comment: "Loading placeholder"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                // Deprecated stages - redirect to new flow
                case .step2_NetworkAndCommitments:
                    PrivacyChoiceView()
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                case .step1_AppInfoView:
                    OnboardingWelcomeIdentityView()
                        .background(QuantumColors.background.ignoresSafeArea())
                case .step3_LegacyAddressCreation:
                    CreateFirstProfile()
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                case .step3_ChooseServerOperators:
                    PrivacyChoiceView()
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                case .step4_SetNotificationsMode:
                    PrivacyChoiceView()
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                case .step4_NetworkCommitments:
                    PrivacyChoiceView()
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                }
            }
        }
        .id(currentStage)
        .popopxBranded()
    }
    
    private func reloadConditionsIfNeeded() {
        guard ChatModel.shared.conditions.serverOperators.isEmpty else { return }
        Task {
            do {
                let conditions = try await apiGetServerOperators()
                await MainActor.run {
                    ChatModel.shared.conditions = conditions
                }
            } catch {
                logger.error("Failed to reload server operators: \(responseError(error))")
            }
        }
    }
}

func onboardingButtonPlaceholder() -> some View {
    Spacer().frame(height: 40)
}

// Spec: spec/client/navigation.md#onboardingStage
enum OnboardingStage: String, Identifiable {
    // New simplified 4-step flow
    case step1_WelcomeIdentity
    case step2_CreateProfile
    case step3_PrivacyChoice
    case step4_GetStarted
    case onboardingComplete

    // Deprecated — mapped via migratePersistedValue
    case step2_NetworkAndCommitments
    case step1_AppInfoView
    case step3_LegacyAddressCreation
    case step3_ChooseServerOperators
    case step4_SetNotificationsMode
    case step4_NetworkCommitments

    public var id: Self { self }

    /// Migrates legacy raw values persisted in UserDefaults from upstream naming.
    static func migratePersistedValue(_ raw: String) -> String {
        switch raw {
        case "step1_PopopXInfo": return "step1_WelcomeIdentity"
        case "step1_AppInfoView": return "step1_WelcomeIdentity"
        case "step2_CreateProfile": return "step2_CreateProfile"
        case "step3_LegacyAddressCreation": return "step2_CreateProfile"
        case "step3_ChooseServerOperators": return "step3_PrivacyChoice"
        case "step4_SetNotificationsMode": return "step3_PrivacyChoice"
        case "step4_NetworkCommitments": return "step3_PrivacyChoice"
        case "step2_NetworkAndCommitments": return "step3_PrivacyChoice"
        default: return raw
        }
    }
}

struct OnboardingStepsView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onboarding: .step1_WelcomeIdentity)
    }
}
