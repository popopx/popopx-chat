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
                        .background(Color(hex: "#06040A").ignoresSafeArea())
                case .step2_NetworkAndCommitments:
                    OnboardingNetworkCommitmentsView()
                        .navigationBarBackButtonHidden(true)
                        .background(Color(hex: "#06040A").ignoresSafeArea())
                case .step1_AppInfoView:
                    AppInfoView(onboarding: true)
                        .modifier(ThemedBackground(glass: true))
                case .step2_CreateProfile:
                    CreateFirstProfile()
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                case .step3_LegacyAddressCreation:
                    CreateFirstProfile()
                        .modifier(ThemedBackground(glass: true))
                case .step3_ChooseServerOperators:
                    YourNetworkView()
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                case .step4_SetNotificationsMode:
                    OnboardingConditionsView(initialOperatorIds: Set(chatModel.conditions.serverOperators.filter { $0.enabled }.map { $0.operatorId }))
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                        .onAppear { reloadConditionsIfNeeded() }
                case .step4_NetworkCommitments:
                    OnboardingConditionsView(initialOperatorIds: Set(chatModel.conditions.serverOperators.filter { $0.enabled }.map { $0.operatorId }))
                        .navigationBarBackButtonHidden(true)
                        .modifier(ThemedBackground(glass: true))
                        .onAppear { reloadConditionsIfNeeded() }
                case .onboardingComplete:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(NSLocalizedString("Loading...", comment: "Loading placeholder"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
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
    case step1_WelcomeIdentity
    case step2_NetworkAndCommitments
    case onboardingComplete
    // Deprecated — mapped via migratePersistedValue
    case step1_AppInfoView
    case step2_CreateProfile
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
        case "step2_CreateProfile": return "step1_WelcomeIdentity"
        case "step3_LegacyAddressCreation": return "step2_NetworkAndCommitments"
        case "step3_ChooseServerOperators": return "step2_NetworkAndCommitments"
        case "step4_SetNotificationsMode": return "step2_NetworkAndCommitments"
        case "step4_NetworkCommitments": return "step2_NetworkAndCommitments"
        default: return raw
        }
    }
}

struct OnboardingStepsView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onboarding: .step1_WelcomeIdentity)
    }
}
