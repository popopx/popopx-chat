//
//  MembershipCardView.swift
//  POPOPX (iOS)
//
//  Membership card purchase and redemption
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct MembershipCardView: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var sub = SubscriptionManager.shared

    @State private var selectedPeriod: BillingPeriod = .yearly
    @State private var redemptionCode: String = ""
    @State private var isRedeeming: Bool = false
    @State private var isPurchasing: Bool = false
    @State private var showRedemptionResult: Bool = false
    @State private var redemptionSuccess: Bool = false
    @State private var redemptionMessage: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                purchaseSection

                Divider().opacity(0.3)

                redemptionSection
            }
            .padding()
        }
        .background(QuantumFieldBackground())
        .navigationTitle(NSLocalizedString("Membership Card", comment: "Membership card title"))
        .navigationBarTitleDisplayMode(.large)
        .modifier(ThemedBackground(grouped: true, glass: true))
        .alert(
            redemptionSuccess
                ? NSLocalizedString("Redemption Successful", comment: "")
                : NSLocalizedString("Redemption Failed", comment: ""),
            isPresented: $showRedemptionResult
        ) {
            Button(NSLocalizedString("OK", comment: "")) {}
        } message: {
            Text(redemptionMessage)
        }
        .popopxBranded()
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 40))
                .foregroundStyle(quantumGradient)
                .shadow(color: QuantumColors.accent.opacity(0.4), radius: 10, x: 0, y: 2)
            Text(NSLocalizedString("POPOPX Membership Card", comment: ""))
                .font(.title2.weight(.bold))
            Text(NSLocalizedString("Purchase a membership card or redeem an existing card code", comment: ""))
                .font(.subheadline)
                .foregroundColor(theme.colors.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Purchase section

    private var purchaseSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "cart.fill").foregroundColor(QuantumColors.accent)
                Text(NSLocalizedString("Purchase Card", comment: ""))
                    .font(.headline)
                Spacer()
            }

            Picker(NSLocalizedString("monetization_billing_period_picker", comment: "Billing period picker label"), selection: $selectedPeriod) {
                ForEach(BillingPeriod.allCases, id: \.self) { period in
                    Text(period.label).tag(period)
                }
            }
            .pickerStyle(.segmented)

            cardDescriptionCard

            purchaseButton
        }
        .padding()
        .glassCard(tint: QuantumColors.accent)
    }

    private var cardDescriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(QuantumColors.accent)
                Text(selectedPeriod == .monthly
                     ? NSLocalizedString("Monthly Card — $9.99", comment: "")
                     : NSLocalizedString("Yearly Card — $99.9", comment: ""))
                    .font(.subheadline.weight(.semibold))
            }

            GlassDivider()

            VStack(alignment: .leading, spacing: 8) {
                cardFeature("checkmark.circle.fill", "Full membership privileges for the billing period")
                cardFeature("checkmark.circle.fill", "All chat, privacy and compute-token features")
                cardFeature("checkmark.circle.fill", "Custom SMP server support")
                cardFeature("checkmark.circle.fill", "Can be gifted to other users")
                if selectedPeriod == .yearly {
                    cardFeature("star.fill", "Save 17% compared to monthly")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(QuantumColors.accent.opacity(0.05))
        )
    }

    private func cardFeature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(QuantumColors.accent)
                .frame(width: 20)
            Text(NSLocalizedString(text, comment: ""))
                .font(.subheadline)
                .foregroundColor(theme.colors.secondary)
            Spacer()
        }
    }

    private var purchaseButton: some View {
        Button {
            purchaseCard()
        } label: {
            HStack(spacing: 8) {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "creditcard.badge.plus")
                }
                Text(isPurchasing
                     ? NSLocalizedString("Processing…", comment: "")
                     : NSLocalizedString("Purchase via App Store", comment: ""))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.white)
            .background(quantumGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: QuantumColors.accent.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .disabled(isPurchasing)
    }

    // MARK: - Redemption section

    private var redemptionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "gift.fill").foregroundColor(QuantumColors.accentSecondary)
                Text(NSLocalizedString("Redeem Card", comment: ""))
                    .font(.headline)
                Spacer()
            }

            Text(NSLocalizedString("Enter the membership card redemption code to activate your subscription.", comment: ""))
                .font(.subheadline)
                .foregroundColor(theme.colors.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField(NSLocalizedString("Enter redemption code", comment: ""), text: $redemptionCode)
                .textFieldStyle(.plain)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(QuantumColors.accent.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(QuantumColors.accent.opacity(0.2), lineWidth: 1)
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)

            Button {
                redeemCard()
            } label: {
                HStack(spacing: 8) {
                    if isRedeeming {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isRedeeming
                         ? NSLocalizedString("Verifying…", comment: "")
                         : NSLocalizedString("Redeem", comment: ""))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [QuantumColors.accentSecondary, QuantumColors.accent],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: QuantumColors.accentSecondary.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .disabled(isRedeeming || redemptionCode.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .glassCard(tint: QuantumColors.accentSecondary)
    }

    // MARK: - Actions

    private func purchaseCard() {
        isPurchasing = true
        Task {
            await sub.refresh()
            let productId = selectedPeriod == .yearly ? PRODUCT_BASIC_YEARLY : PRODUCT_BASIC_MONTHLY
            if let product = sub.product(productId) {
                await sub.purchase(product)
            }
            isPurchasing = false
        }
    }

    private func redeemCard() {
        let code = redemptionCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        isRedeeming = true
        Task {
            let result = await MembershipCardAPI.shared.redeem(code: code)
            await MainActor.run {
                isRedeeming = false
                switch result {
                case .success(let message):
                    redemptionSuccess = true
                    redemptionMessage = message
                    redemptionCode = ""
                case .failure(let message):
                    redemptionSuccess = false
                    redemptionMessage = message
                }
                showRedemptionResult = true
            }
        }
    }
}

// MARK: - Membership Card API

enum MembershipCardRedemptionResult {
    case success(String)
    case failure(String)
}

@MainActor
class MembershipCardAPI: ObservableObject {
    static let shared = MembershipCardAPI()

    func redeem(code: String) async -> MembershipCardRedemptionResult {
        let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count >= 8 else {
            return .failure(NSLocalizedString("Invalid code format. Please check and try again.", comment: ""))
        }

        guard let user = ChatModel.shared.currentUser else {
            return .failure(NSLocalizedString("Please complete setup first.", comment: ""))
        }

        do {
            guard let redeemed = try await apiRedeemBadgeCode(user.userId, trimmed) else {
                return .failure(NSLocalizedString("Redemption code not found.", comment: ""))
            }
            if let badgeState = redeemed.badgeState, !badgeState.shown {
                return .failure(NSLocalizedString("This code has already been redeemed.", comment: ""))
            }
            return .success(NSLocalizedString("Membership activated successfully!", comment: ""))
        } catch {
            return .failure(NSLocalizedString("Network error. Please check your connection.", comment: ""))
        }
    }
}
