//
//  MonetizationViews.swift
//  POPOPX (iOS)
//
//  Complete StoreKit 2 payment UI:
//  - Subscription view with monthly/yearly toggle, status card, success feedback
//  - Paywall with full-app lock
//  - Compute-token store with purchase flow
//  - Red packet composer and chat bubble
//  - Subscription renewal via iOS manage sheet
//  - Trial reminder banner
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import StoreKit
import POPOPXSwitch

// MARK: - POPOPX Brand Colors (use QuantumColors from QuantumTheme.swift)

private let privacyPolicyURL = URL(string: "https://popopxchat.com/privacy") ?? URL(fileURLWithPath: NSTemporaryDirectory())
private let termsOfServiceURL = URL(string: "https://popopxchat.com/terms") ?? URL(fileURLWithPath: NSTemporaryDirectory())

var quantumGradient: LinearGradient {
    LinearGradient(colors: [QuantumColors.accent, QuantumColors.accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
}

var quantumGoldGradient: LinearGradient {
    LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFFF5470)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct GlassCard: ViewModifier {
    var tint: Color = QuantumColors.accentSecondary
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        
        content
            .background(isDark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.thickMaterial))
            .background(isDark ? Color(hex: "#181829").opacity(0.85) : Color(hex: "#F1ECF7").opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(quantumGradient.opacity(isDark ? 0.6 : 0.7), lineWidth: 1)
            )
            .shadow(color: isDark ? QuantumColors.accent.opacity(0.15) : QuantumColors.accentSecondary.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func glassCard(tint: Color = QuantumColors.accentSecondary) -> some View { modifier(GlassCard(tint: tint)) }
}

struct GradientButton: View {
    var title: LocalizedStringKey
    var systemImage: String? = nil
    var gradient: LinearGradient = quantumGradient
    var disabled: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    var action: () -> Void

    var body: some View {
        let isDark = colorScheme == .dark
        
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.white)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: isDark ? QuantumColors.accent.opacity(0.5) : QuantumColors.accentSecondary.opacity(0.4), radius: 12, x: 0, y: 6)
            .shadow(color: isDark ? QuantumColors.accentSecondary.opacity(0.3) : QuantumColors.accent.opacity(0.2), radius: 8, x: 0, y: 4)
            .opacity(disabled ? 0.5 : 1)
        }
        .disabled(disabled)
        .popopxBranded()
    }
}

struct FeatureChip: View {
    var icon: String
    var text: LocalizedStringKey
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let isDark = colorScheme == .dark
        
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(quantumGradient)
                .frame(width: 22)
                .shadow(color: isDark ? QuantumColors.accent.opacity(0.4) : QuantumColors.accentSecondary.opacity(0.3), radius: 6, x: 0, y: 0)
            Text(text).font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - Subscription view

struct SubscriptionView: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var sub = SubscriptionManager.shared

    @State private var billingPeriod: BillingPeriod = .yearly
    @State private var showPurchaseSuccess = false
    @State private var showErrorAlert = false
    @State private var isRestoring = false
    @State private var purchasingProductId: String?
    @State private var dismissSuccessWorkItem: DispatchWorkItem?

    var showVoucherRedemption: Bool = true

    @State private var voucherCode: String = ""
    @State private var isRedeemingVoucher: Bool = false
    @State private var voucherRedemptionMessage: String = ""
    @State private var showVoucherResult: Bool = false
    @State private var voucherRedemptionSuccess: Bool = false
    @State private var showVoucherSuccessOverlay: Bool = false
    @State private var voucherSuccessPeriod: BillingPeriod = .yearly
    @State private var dismissVoucherOverlayWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack {
            // Ambient obsidian background with subtle orb glow
            Color(hex: "#0A0A14")
                .ignoresSafeArea()
            RadialGradient(
                colors: [QuantumColors.accent.opacity(0.08), QuantumColors.accentSecondary.opacity(0.04), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    header

                    if sub.hasActiveSubscription {
                        subscriptionStatusCard
                    }

                    billingToggle

                    restorePurchasesButton

                    tierCards

                    if showVoucherRedemption {
                        voucherRedemptionSection
                    }

                    if let err = sub.lastSubscriptionError {
                        Text(err.errorDescription ?? "").font(.footnote).foregroundColor(QuantumColors.error)
                    }

                    footerLinks
                }
                .padding()
            }
        }
        .navigationTitle(NSLocalizedString("Membership", comment: ""))
        .task {
            await sub.refresh()
        }
        .onChange(of: sub.purchaseSuccess) {_, success in
            if success {
                purchasingProductId = nil
                withAnimation { showPurchaseSuccess = true }
                dismissSuccessWorkItem?.cancel()
                let workItem = DispatchWorkItem {
                    withAnimation { showPurchaseSuccess = false }
                }
                dismissSuccessWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
            }
        }
        .onChange(of: sub.lastSubscriptionError) {_, error in
            showErrorAlert = error != nil
            purchasingProductId = nil
        }
        .alert(NSLocalizedString("Purchase Error", comment: ""), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("OK", comment: "")) { sub.lastSubscriptionError = nil }
        } message: {
            Text(sub.lastSubscriptionError?.errorDescription ?? NSLocalizedString("Unknown error", comment: ""))
        }
        .overlay {
            if showPurchaseSuccess {
                subscriptionSuccessOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showPurchaseSuccess)
        .overlay {
            if showVoucherSuccessOverlay {
                voucherSuccessOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showVoucherSuccessOverlay)
        .alert(
            voucherRedemptionSuccess
                ? NSLocalizedString("voucher_redeem_success_title", comment: "")
                : NSLocalizedString("voucher_redeem_failed_title", comment: ""),
            isPresented: $showVoucherResult
        ) {
            Button(NSLocalizedString("OK", comment: "")) {}
        } message: {
            Text(voucherRedemptionMessage)
        }
        .onDisappear {
            dismissSuccessWorkItem?.cancel()
            dismissVoucherOverlayWorkItem?.cancel()
        }
    }

    private var restorePurchasesButton: some View {
        Button {
            Task {
                isRestoring = true
                await sub.restore()
                isRestoring = false
            }
        } label: {
            HStack(spacing: 8) {
                if isRestoring {
                    ProgressView()
                        .tint(QuantumColors.accent)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text(isRestoring
                     ? NSLocalizedString("Restoring…", comment: "")
                     : NSLocalizedString("Restore purchases", comment: ""))
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundColor(QuantumColors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(QuantumColors.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(QuantumColors.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isRestoring)
    }

    private var footerLinks: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Link(NSLocalizedString("Privacy Policy", comment: ""), destination: privacyPolicyURL)
                Link(NSLocalizedString("Terms of Service", comment: ""), destination: termsOfServiceURL)
                Link(NSLocalizedString("monetization_eula_link", comment: "EULA link label"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            }
            .font(.caption)
            .foregroundColor(theme.colors.secondary)

            Text(NSLocalizedString(
                "Your subscription will automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in Settings on your device after purchase.",
                comment: "Auto-renewal subscription terms disclosure required by Apple"
            ))
            .font(.caption)
            .foregroundColor(theme.colors.secondary.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 44))
                .foregroundStyle(quantumGradient)
                .shadow(color: QuantumColors.accent.opacity(0.6), radius: 16, x: 0, y: 0)
                .shadow(color: QuantumColors.accentSecondary.opacity(0.4), radius: 24, x: 0, y: 0)
            Text(LocalizedStringKey("POPOPX Quantum"))
                .font(.title2.weight(.heavy))
                .foregroundStyle(LinearGradient(
                    colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .shadow(color: QuantumColors.accent.opacity(0.5), radius: 12, x: 0, y: 2)
            statusTextView
                .font(.caption)
                .foregroundColor(QuantumColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusTextView: some View {
        if sub.hasActiveSubscription {
            Text(NSLocalizedString("Member", comment: "Active membership status"))
        } else if sub.trialActive {
            Text(String(format: NSLocalizedString("free_trial_days_left", comment: "Free trial · %d day(s) left"), sub.trialDaysLeft))
        } else {
            Text(NSLocalizedString("Trial ended — choose a plan", comment: ""))
        }
    }

    private var subscriptionStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(quantumGradient)
                    .font(.title3)
                Text(NSLocalizedString("Active Subscription", comment: ""))
                    .font(.headline)
                Spacer()
            }

            if let info = sub.subscriptionInfo {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Plan", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(theme.colors.secondary)
                        Spacer()
                        Text(NSLocalizedString("Membership", comment: "Unified membership plan name"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text(NSLocalizedString("Expires", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(theme.colors.secondary)
                        Spacer()
                        Text(info.expiresAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                    }

                    HStack {
                        Text(NSLocalizedString("Auto-renewal", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(theme.colors.secondary)
                        Spacer()
                        Text(info.autoRenew ? NSLocalizedString("On", comment: "") : NSLocalizedString("Off", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(info.autoRenew ? QuantumColors.success : QuantumColors.warning)
                    }

                    #if DEBUG
                    HStack {
                        Text(NSLocalizedString("Environment", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(theme.colors.secondary)
                        Spacer()
                        Text(info.environment)
                            .font(.subheadline)
                            .foregroundColor(theme.colors.secondary)
                    }
                    #endif
                }
            } else if let expiry = sub.subscriptionExpirationDate {
                HStack {
                    Text(NSLocalizedString("Expires", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(theme.colors.secondary)
                    Spacer()
                    Text(expiry.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                }
            }

            manageSubscriptionButton
        }
        .padding()
        .glassCard(tint: QuantumColors.success)
    }

    private var manageSubscriptionButton: some View {
        Button {
            Task {
                #if canImport(UIKit)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    await sub.showManageSubscriptions(in: windowScene)
                }
                #endif
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gear")
                Text(NSLocalizedString("Manage Subscription", comment: ""))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(QuantumColors.accentSecondary)
            .background(QuantumColors.accentSecondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(QuantumColors.accentSecondary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var billingToggle: some View {
        Picker(NSLocalizedString("monetization_billing_period_picker", comment: "Billing period picker label"), selection: $billingPeriod) {
            ForEach(BillingPeriod.allCases, id: \.self) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var tierCards: some View {
        let tierProducts = sub.products(for: billingPeriod)

        if tierProducts.isEmpty && !sub.loading {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundColor(QuantumColors.warning)
                Text(NSLocalizedString("Unable to load subscription products. Please check your network connection and try again.", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(theme.colors.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await sub.refresh() }
                } label: {
                    Text(NSLocalizedString("Retry", comment: ""))
                        .fontWeight(.medium)
                }
                .tint(QuantumColors.accent)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }

        let productId = billingPeriod == .yearly ? PRODUCT_BASIC_YEARLY : PRODUCT_BASIC_MONTHLY
        let fallbackPrice: LocalizedStringKey = billingPeriod == .yearly ? LocalizedStringKey(NSLocalizedString("monetization_price_yearly", comment: "Yearly price fallback")) : LocalizedStringKey(NSLocalizedString("monetization_price_monthly", comment: "Monthly price fallback"))
        membershipCard(
            product: tierProducts.first { $0.id == productId },
            fallbackPrice: fallbackPrice
        )
    }

    @ViewBuilder
    private func membershipCard(product: Product?, fallbackPrice: LocalizedStringKey) -> some View {
        let owned = sub.hasActiveSubscription
        let isPurchasing = purchasingProductId != nil && purchasingProductId == product?.id
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(NSLocalizedString("Membership Subscription", comment: "Unified membership card title")).font(.title3).bold()
                Spacer()
                if let product {
                    Text(product.displayPrice).font(.headline).foregroundStyle(quantumGradient)
                } else {
                    Text(fallbackPrice).font(.headline).foregroundStyle(quantumGradient)
                }
            }
            FeatureChip(icon: "checkmark.seal", text: LocalizedStringKey(NSLocalizedString("monetization_feature_chat_privacy", comment: "Feature chip text")))
            FeatureChip(icon: "bolt", text: LocalizedStringKey(NSLocalizedString("monetization_feature_compute_gifts", comment: "Feature chip text")))
            FeatureChip(icon: "server.rack", text: LocalizedStringKey(NSLocalizedString("monetization_feature_own_servers", comment: "Feature chip text")))
            FeatureChip(icon: "sparkles", text: LocalizedStringKey(NSLocalizedString("monetization_feature_quantum", comment: "Feature chip text")))
            if owned {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(QuantumColors.success)
                    Text(NSLocalizedString("Current plan", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                    Spacer()
                }
            } else if isPurchasing {
                HStack {
                    ProgressView()
                        .tint(QuantumColors.accent)
                    Text(NSLocalizedString("Processing…", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(theme.colors.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                GradientButton(
                    title: LocalizedStringKey(String(format: NSLocalizedString("Subscribe", comment: ""), product?.displayPrice ?? "")),
                    systemImage: "sparkles",
                    gradient: quantumGradient,
                    disabled: product == nil
                ) {
                    if let product {
                        purchasingProductId = product.id
                        Task { await sub.purchase(product) }
                    }
                }
            }
        }
        .padding()
        .glassCard(tint: QuantumColors.accent)
        .quantumGlowBorder(color: QuantumColors.accent, cornerRadius: 18)
    }

    // MARK: - Voucher code redemption

    private var voucherRedemptionSection: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(QuantumColors.accentSecondary)
                Text(NSLocalizedString("voucher_code_title", comment: ""))
                    .font(.headline)
                Spacer()
            }

            TextField(NSLocalizedString("voucher_code_placeholder", comment: ""), text: $voucherCode)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#1A1A2E"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(QuantumColors.accent.opacity(0.3), lineWidth: 1)
                )
                .foregroundStyle(Color.white)
                .tint(QuantumColors.accent)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)

            Button {
                redeemVoucher()
            } label: {
                HStack(spacing: 8) {
                    if isRedeemingVoucher {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle")
                    }
                    Text(isRedeemingVoucher
                         ? NSLocalizedString("voucher_verifying", comment: "")
                         : NSLocalizedString("voucher_redeem_button", comment: ""))
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
            .disabled(isRedeemingVoucher || voucherCode.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .glassCard(tint: QuantumColors.accentSecondary)
    }

    private var voucherSuccessOverlay: some View {
        ZStack {
            Color(hex: "#0A0A14").opacity(0.8).ignoresSafeArea()
            RadialGradient(
                colors: [QuantumColors.accentSecondary.opacity(0.15), QuantumColors.accent.opacity(0.08), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 250
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [QuantumColors.accentSecondary, QuantumColors.accent],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: QuantumColors.accentSecondary.opacity(0.7), radius: 24, x: 0, y: 0)
                        .shadow(color: QuantumColors.accent.opacity(0.5), radius: 32, x: 0, y: 0)
                    Image(systemName: "checkmark")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.white)
                }

                Text(NSLocalizedString("voucher_activated_title", comment: ""))
                    .font(.title2).bold().foregroundColor(.white)

                VStack(spacing: 4) {
                    Text(voucherSuccessPeriod == .yearly
                         ? NSLocalizedString("voucher_yearly_membership", comment: "")
                         : NSLocalizedString("voucher_monthly_membership", comment: ""))
                        .font(.title.weight(.bold))
                        .foregroundColor(QuantumColors.accentSecondary)
                        .shadow(color: QuantumColors.accentSecondary.opacity(0.6), radius: 8, x: 0, y: 0)
                    Text(NSLocalizedString("voucher_membership_activated", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                Button {
                    withAnimation { showVoucherSuccessOverlay = false }
                } label: {
                    Text(NSLocalizedString("Continue", comment: ""))
                        .fontWeight(.semibold)
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
                        .shadow(color: QuantumColors.accentSecondary.opacity(0.5), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(Color(hex: "#181829").opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [QuantumColors.accentSecondary, QuantumColors.accent],
                                    startPoint: .leading, endPoint: .trailing
                                ).opacity(0.6),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: QuantumColors.accentSecondary.opacity(0.3), radius: 16, x: 0, y: 8)
            )
            .padding(.horizontal, 32)
        }
    }

    private func redeemVoucher() {
        let code = voucherCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        isRedeemingVoucher = true
        Task {
            let result = await MembershipCardAPI.shared.redeem(code: code)
            await MainActor.run {
                isRedeemingVoucher = false
                switch result {
                case .success(let message):
                    voucherRedemptionSuccess = true
                    voucherRedemptionMessage = message
                    voucherSuccessPeriod = billingPeriod
                    voucherCode = ""
                    withAnimation { showVoucherSuccessOverlay = true }
                    dismissVoucherOverlayWorkItem?.cancel()
                    let workItem = DispatchWorkItem {
                        withAnimation { showVoucherSuccessOverlay = false }
                    }
                    dismissVoucherOverlayWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
                    Task { await sub.refresh() }
                case .failure(let message):
                    voucherRedemptionSuccess = false
                    voucherRedemptionMessage = message
                    showVoucherResult = true
                }
            }
        }
    }

    private var subscriptionSuccessOverlay: some View {
        ZStack {
            Color(hex: "#0A0A14").opacity(0.8).ignoresSafeArea()
            RadialGradient(
                colors: [QuantumColors.accent.opacity(0.15), QuantumColors.accentSecondary.opacity(0.08), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 250
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(quantumGradient)
                        .frame(width: 90, height: 90)
                        .shadow(color: QuantumColors.accent.opacity(0.7), radius: 24, x: 0, y: 0)
                        .shadow(color: QuantumColors.accentSecondary.opacity(0.5), radius: 32, x: 0, y: 0)
                    Image(systemName: "checkmark")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.white)
                }

                Text(NSLocalizedString("Subscription Active", comment: "")).font(.title2).bold().foregroundColor(.white)

                VStack(spacing: 4) {
                    Text(NSLocalizedString("Membership", comment: "Unified membership plan name"))
                        .font(.title.weight(.bold))
                        .foregroundColor(QuantumColors.accent)
                        .shadow(color: QuantumColors.accent.opacity(0.6), radius: 8, x: 0, y: 0)
                    Text(NSLocalizedString("membership activated", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                Button {
                    withAnimation { showPurchaseSuccess = false }
                } label: {
                    Text(NSLocalizedString("Continue", comment: "")).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(quantumGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: QuantumColors.accent.opacity(0.5), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(Color(hex: "#181829").opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(quantumGradient.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: QuantumColors.accent.opacity(0.3), radius: 16, x: 0, y: 8)
            )
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Paywall (full lock when trial ends)

struct PaywallView: View {
    var body: some View {
        NavigationStack {
            SubscriptionView(showVoucherRedemption: true)
                .navigationTitle(NSLocalizedString("Subscription required", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
                .interactiveDismissDisabled(true)
        }
    }
}

// MARK: - Compute-token store

struct ComputeStoreView: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var store = ComputeStore.shared

    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    @State private var confirmingProduct: ComputeProduct?
    @State private var purchaseAlert: PurchaseAlert?
    @State private var showSuccess: Bool = false
    @State private var successTokens: Double = 0
    @State private var animateBalance: Bool = false
    @State private var showSendRedPacket: Bool = false
    @State private var redPacketFromStoreAlert: RedPacketInfo? = nil
    @State private var dismissSuccessWorkItem: DispatchWorkItem?

    private struct PurchaseAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        ZStack {
            // Ambient obsidian background with subtle orb glow
            Color(hex: "#0A0A14")
                .ignoresSafeArea()
            RadialGradient(
                colors: [QuantumColors.accentWarm.opacity(0.06), QuantumColors.accentSecondary.opacity(0.03), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    balanceCard

                    // Red packets can only be sent from a chat conversation; disabled here to avoid dead end.
                    Button {
                        showSendRedPacket = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "gift.fill").font(.title3).foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("Send compute red packet", comment: "")).font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                                Text(NSLocalizedString("Gift tokens to a contact", comment: "")).font(.caption).foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(quantumGoldGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color(0xFFFF5470).opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .disabled(true) // Red packets can only be sent from a chat conversation
                    .opacity(0.5)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.products) { p in productCard(p) }
                    }
                    if let err = store.lastError, store.purchasingProductId == nil {
                        Text(err).font(.footnote).foregroundColor(theme.colors.secondary)
                    }

                    HStack(spacing: 16) {
                        Link(NSLocalizedString("Privacy Policy", comment: ""), destination: privacyPolicyURL)
                        Link(NSLocalizedString("Terms of Service", comment: ""), destination: termsOfServiceURL)
                        Link(NSLocalizedString("monetization_eula_link", comment: "EULA link label"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") ?? URL(fileURLWithPath: NSTemporaryDirectory()))
                    }
                    .font(.caption)
                    .foregroundColor(theme.colors.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding()
            }
            
            if showSuccess {
                successOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSuccess)
        .onDisappear {
            dismissSuccessWorkItem?.cancel()
        }
        .navigationTitle(NSLocalizedString("Compute store", comment: ""))
        .task {
            await store.loadProducts()
            await store.loadStoreKitProducts()
            await store.refreshBalance()
        }
        .confirmationDialog(
            NSLocalizedString("Confirm Order", comment: ""),
            isPresented: Binding(
                get: { confirmingProduct != nil },
                set: { if !$0 { confirmingProduct = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let p = confirmingProduct {
                Button {
                    executePurchase(p)
                } label: {
                    Text(LocalizedStringKey(String(format: NSLocalizedString("monetization_pay_price", comment: "pay button with price"), store.storeKitProducts.first { $0.id == p.storeKitProductId }?.displayPrice ?? p.priceUSD.formatted(.currency(code: "USD")))))
                }
                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) { confirmingProduct = nil }
            }
        } message: {
            if let p = confirmingProduct {
                Text(String(format: NSLocalizedString("compute_purchase_format", comment: ""), p.title, formatTokens(p.tokenAmount)))
            }
        }
        .alert(item: $purchaseAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text(LocalizedStringKey("OK"))))
        }
        .sheet(isPresented: $showSendRedPacket) {
            SendRedPacketView(onSend: { packet in
                showSendRedPacket = false
                redPacketFromStoreAlert = packet
            })
            .environmentObject(theme)
        }
        .alert(item: $redPacketFromStoreAlert) { packet in
            Alert(
                title: Text(NSLocalizedString("Send from a Chat", comment: "")),
                message: Text(NSLocalizedString("Red packets can only be sent from a chat conversation. Open a chat and tap the token gift button to send a red packet.", comment: "")),
                dismissButton: .default(Text(LocalizedStringKey("OK")))
            )
        }
    }

    private var balanceCard: some View {
        VStack(spacing: 6) {
            Text(NSLocalizedString("Compute-token balance", comment: "")).font(.subheadline).foregroundColor(theme.colors.secondary)
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").foregroundStyle(quantumGradient)
                Text(formatTokens(store.balance))
                    .font(.title.bold())
                    .foregroundColor(animateBalance ? QuantumColors.accent : theme.colors.onBackground)
                    .scaleEffect(animateBalance ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.4), value: animateBalance)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard()
        .quantumGlowBorder(color: QuantumColors.accentWarm, cornerRadius: 18)
    }

    private func productCard(_ p: ComputeProduct) -> some View {
        let isPurchasing = store.purchasingProductId == p.id
        let skProduct = store.storeKitProducts.first { $0.id == p.storeKitProductId }
        let displayPrice = skProduct?.displayPrice ?? p.priceUSD.formatted(.currency(code: "USD"))

        return VStack(spacing: 10) {
            Image(systemName: p.icon).font(.system(size: 30)).foregroundStyle(quantumGradient)
            Text(p.title).font(.headline)
            Text(String(format: NSLocalizedString("tokens_count_format", comment: ""), formatTokens(p.tokenAmount))).font(.subheadline).foregroundColor(theme.colors.secondary)
            if isPurchasing {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                GradientButton(title: LocalizedStringKey(displayPrice), disabled: store.loading) {
                    confirmingProduct = p
                }
            }
        }
        .padding()
        .glassCard()
        .quantumGlowBorder(color: QuantumColors.accent, cornerRadius: 18)
    }

    private var successOverlay: some View {
        ZStack {
            Color(hex: "#0A0A14").opacity(0.8).ignoresSafeArea()
            RadialGradient(
                colors: [QuantumColors.accentWarm.opacity(0.12), QuantumColors.accentSecondary.opacity(0.06), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 250
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(quantumGoldGradient)
                        .frame(width: 90, height: 90)
                        .shadow(color: Color(0xFFFFB74D).opacity(0.6), radius: 24, x: 0, y: 0)
                        .shadow(color: Color(0xFFFF5470).opacity(0.4), radius: 32, x: 0, y: 0)
                    Image(systemName: "checkmark")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.white)
                }

                Text(NSLocalizedString("Payment Successful", comment: "")).font(.title2).bold().foregroundColor(.white)

                VStack(spacing: 4) {
                    Text(String(format: NSLocalizedString("tokens_success_format", comment: ""), formatTokens(successTokens))).font(.title2.bold()).foregroundColor(QuantumColors.accentWarm)
                        .shadow(color: QuantumColors.accentWarm.opacity(0.5), radius: 8, x: 0, y: 0)
                    Text(NSLocalizedString("credited to your balance", comment: "")).font(.subheadline).foregroundColor(.white.opacity(0.7))
                }

                VStack(spacing: 6) {
                    Text(NSLocalizedString("Current balance", comment: "")).font(.caption).foregroundColor(.white.opacity(0.75))
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill").font(.caption).foregroundColor(QuantumColors.accentWarm)
                        Text(formatTokens(store.balance)).font(.headline).foregroundColor(.white)
                            .shadow(color: QuantumColors.accentWarm.opacity(0.4), radius: 6, x: 0, y: 0)
                    }
                }
                .padding(.top, 4)

                Button {
                    withAnimation { showSuccess = false }
                    animateBalance = false
                } label: {
                    Text(NSLocalizedString("Continue", comment: "")).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(quantumGoldGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color(0xFFFF5470).opacity(0.5), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(Color(hex: "#181829").opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(quantumGoldGradient.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: Color(0xFFFF5470).opacity(0.3), radius: 16, x: 0, y: 8)
            )
            .padding(.horizontal, 32)
        }
    }

    private func executePurchase(_ product: ComputeProduct) {
        confirmingProduct = nil
        Task {
            let balanceBefore = store.balance
            let result = await store.purchase(product)
            switch result {
            case .success:
                let credited = store.balance - balanceBefore
                successTokens = credited > 0 ? credited : product.tokenAmount
                withAnimation { showSuccess = true }
                animateBalance = true
                dismissSuccessWorkItem?.cancel()
                let workItem = DispatchWorkItem {
                    withAnimation { showSuccess = false }
                    animateBalance = false
                }
                dismissSuccessWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
            case .pending:
                purchaseAlert = PurchaseAlert(
                    title: NSLocalizedString("purchase_pending_title", comment: ""),
                    message: NSLocalizedString("purchase_pending_message", comment: "")
                )
            case .cancelled:
                break
            case .failure(let msg):
                purchaseAlert = PurchaseAlert(title: String(localized: "Purchase Failed"), message: msg)
            }
        }
    }
}

// MARK: - Send red packet

struct SendRedPacketView: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var store = ComputeStore.shared
    @Environment(\.dismiss) var dismiss
    var onSend: (RedPacketInfo) -> Void

    @State private var amountStr: String = ""
    @State private var message: String = ""

    private var amount: Double { Double(amountStr) ?? 0 }
    private var canSend: Bool { amount > 0 && amount <= store.balance }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Image(systemName: "gift.fill").font(.title2).foregroundStyle(quantumGoldGradient)
                        Text(NSLocalizedString("Compute-token red packet", comment: "")).font(.title3).bold()
                        Text(String(format: NSLocalizedString("tokens_balance_format", comment: ""), formatTokens(store.balance)))
                            .font(.footnote).foregroundColor(theme.colors.secondary)
                    }
                    .frame(maxWidth: .infinity).padding().glassCard(tint: QuantumColors.accentSecondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("Amount", comment: "")).font(.subheadline).foregroundColor(theme.colors.secondary)
                        TextField("0", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .font(.system(.largeTitle).weight(.bold))
                        GlassDivider()
                        Text(NSLocalizedString("Greeting", comment: "")).font(.subheadline).foregroundColor(theme.colors.secondary)
                        TextField(NSLocalizedString("Best wishes!", comment: ""), text: $message)
                    }
                    .padding().glassCard()

                    GradientButton(title: LocalizedStringKey(NSLocalizedString("Send red packet", comment: "")), systemImage: "paperplane.fill", gradient: quantumGoldGradient, disabled: !canSend) {
                        let packet = RedPacketInfo(
                            id: UUID().uuidString,
                            amount: amount,
                            message: message,
                            from: ChatModel.shared.currentUser?.displayName ?? ""
                        )
                        onSend(packet)
                        dismiss()
                    }
                    if amount > store.balance {
                        HStack {
                            Text(NSLocalizedString("Not enough tokens.", comment: "")).font(.footnote).foregroundColor(QuantumColors.error)
                            Button(NSLocalizedString("Recharge", comment: "")) {
                                dismiss()
                                ChatModel.shared.showKeyRotationNotice = false
                                ChatModel.shared.showComputeStore = true
                            }
                            .font(.footnote).fontWeight(.semibold)
                        }
                    }
                }
                .padding()
            }
            .modifier(ThemedBackground(grouped: true))
            .navigationTitle(NSLocalizedString("Red packet", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(NSLocalizedString("Cancel", comment: "")) { dismiss() } } }
        }
    }
}

// MARK: - Red packet chat bubble

struct CIRedPacketView: View {
    @EnvironmentObject var theme: AppTheme
    var chatItem: ChatItem
    var packet: RedPacketInfo
    var maxWidth: CGFloat = .infinity

    @State private var refresh = false
    @State private var showClaimSuccess = false
    @State private var claiming = false

    private var isClaimed: Bool { EntitlementStore.shared.isClaimed(packet.id) }
    private var isSent: Bool { chatItem.chatDir.sent }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "gift.fill").font(.title2).foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(packet.message.isEmpty ? NSLocalizedString("Compute-token gift", comment: "") : packet.message)
                            .font(.headline).foregroundColor(.white)
                        Text(LocalizedStringKey("\(formatTokens(packet.amount)) tokens"))
                            .font(.subheadline).foregroundColor(.white.opacity(0.9))
                    }
                }
                GlassDivider()
                actionTextView
                    .font(.footnote).foregroundColor(.white.opacity(0.9))
            }
            .padding(14)
            .frame(maxWidth: maxWidth == .infinity ? 260 : maxWidth, alignment: .leading)
            .background(quantumGoldGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .id(refresh)
            .onTapGesture { claim() }

            if showClaimSuccess {
                claimSuccessOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showClaimSuccess)
    }

    @ViewBuilder
    private var actionTextView: some View {
        if isSent {
            Text(NSLocalizedString("You sent this red packet", comment: ""))
        } else if isClaimed {
            Text(NSLocalizedString("Claimed", comment: ""))
        } else {
            Text(NSLocalizedString("Tap to claim compute tokens", comment: ""))
        }
    }

    private var claimSuccessOverlay: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(.title).weight(.bold))
                .foregroundColor(.white)
            Text(LocalizedStringKey("+\(formatTokens(packet.amount)) tokens"))
                .font(.system(.subheadline).weight(.bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: maxWidth == .infinity ? 260 : maxWidth)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(0xFFFF5470).opacity(0.9))
        )
    }

    private func claim() {
        guard !isSent, !isClaimed, !showClaimSuccess, !claiming, packet.amount > 0 else { return }
        claiming = true
        Task {
            let ok = await ComputeStore.shared.claimGift(id: packet.id, amount: packet.amount)
            if ok {
                EntitlementStore.shared.markClaimed(packet.id)
                withAnimation { showClaimSuccess = true }
                refresh.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showClaimSuccess = false }
                }
            }
            claiming = false
        }
    }
}

// MARK: - Subscription renewal reminder

struct SubscriptionRenewalView: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var sub = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // Ambient obsidian background
            Color(hex: "#0A0A14")
                .ignoresSafeArea()
            RadialGradient(
                colors: [Color(0xFFFFB74D).opacity(0.1), Color(0xFFFF5470).opacity(0.06), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 280
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(AnyShapeStyle(LinearGradient(
                            colors: [Color(0xFFFFB74D), Color(0xFFFF5470)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )))
                        .frame(width: 80, height: 80)
                        .shadow(color: Color(0xFFFF5470).opacity(0.6), radius: 20, x: 0, y: 8)
                        .shadow(color: Color(0xFFFFB74D).opacity(0.4), radius: 28, x: 0, y: 0)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.3), radius: 4, x: 0, y: 0)
                }
                .padding(.top, 20)

                VStack(spacing: 8) {
                    Text(NSLocalizedString("Subscription Expiring Soon", comment: ""))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .shadow(color: Color(0xFFFF5470).opacity(0.4), radius: 8, x: 0, y: 2)

                    if let days = sub.daysUntilExpiration {
                        (Text(String(format: NSLocalizedString("membership_expires_in_days", comment: "Your %@ membership expires in %d day(s)."), NSLocalizedString("Membership", comment: "Unified membership plan name"), days)))
                            .font(.subheadline)
                            .foregroundColor(theme.colors.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    GradientButton(
                        title: LocalizedStringKey(NSLocalizedString("Manage Subscription", comment: "")),
                        systemImage: "gear",
                        gradient: quantumGradient
                    ) {
                        Task {
                            #if canImport(UIKit)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                await sub.showManageSubscriptions(in: windowScene)
                            }
                            #endif
                            dismiss()
                        }
                    }

                    Button(NSLocalizedString("Maybe Later", comment: "")) {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(theme.colors.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}

// MARK: - Trial reminder banner

struct TrialReminderBanner: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var sub = SubscriptionManager.shared
    var onSubscribe: () -> Void

    private var urgencyColor: (Color, Color) {
        switch sub.trialUrgency {
        case .low: return (QuantumColors.accent, QuantumColors.accentSecondary)
        case .medium: return (Color(0xFFFFB74D), Color(0xFFFF9100))
        case .high: return (Color(0xFFFF5470), Color(0xFFFF1744))
        case .critical: return (Color(0xFFFF1744), Color(0xFFD50000))
        }
    }

    var body: some View {
        let (c1, c2) = urgencyColor
        HStack(spacing: 12) {
            Image(systemName: sub.trialUrgency == .low ? "sparkles" : "exclamationmark.triangle.fill")
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.3), radius: 4, x: 0, y: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(sub.trialUrgency.message(days: sub.trialDaysLeft))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                if sub.trialDaysLeft > 0 {
                    Text(String(format: NSLocalizedString("trial_days_remaining", comment: "%d day(s) remaining"), sub.trialDaysLeft))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer()

            Button(action: onSubscribe) {
                Text(NSLocalizedString("Subscribe", comment: ""))
                    .font(.caption.weight(.bold))
                    .foregroundColor(c1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white))
                    .shadow(color: c1.opacity(0.5), radius: 6, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(LinearGradient(colors: [c1, c2], startPoint: .leading, endPoint: .trailing))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: c1.opacity(0.4), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
