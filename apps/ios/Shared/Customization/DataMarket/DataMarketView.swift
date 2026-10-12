// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import Foundation

// MARK: - Data Market View

struct DataMarketView: View {
    @ObservedObject private var manager = DataMarketManager.shared
    @EnvironmentObject var computeStore: ComputeStore

    @State private var selectedTab: MarketTab = .marketplace
    @State private var newTitle: String = ""
    @State private var newDescription: String = ""
    @State private var newPrice: Double = 0
    @State private var newCategory: DataCategory = .browsingHistory
    @State private var showCreateForm = false
    @State private var showPurchaseConfirm = false
    @State private var listingToPurchase: DataListing?
    @State private var purchaseError: String?

    enum MarketTab: String, CaseIterable {
        case marketplace = "Marketplace"
        case myListings = "My Listings"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                comingSoonBanner
                headerSection
                tabSelector
                createListingSection
                listingsSection
            }
            .padding()
        }
        .background(QuantumColors.background.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("Data Marketplace", comment: "data market view title"))
        .alert(NSLocalizedString("Confirm Purchase", comment: "purchase confirmation alert title"), isPresented: $showPurchaseConfirm) {
            Button(NSLocalizedString("Cancel", comment: "cancel purchase button"), role: .cancel) {
                listingToPurchase = nil
            }
            Button(NSLocalizedString("Purchase", comment: "confirm purchase button")) {
                if let listing = listingToPurchase {
                    executePurchase(listing)
                }
            }
        } message: {
            if let listing = listingToPurchase {
                let priceStr = String(format: "%.1f", listing.price)
                Text(String(format: NSLocalizedString("market_purchase_confirm_format", comment: ""), listing.title, priceStr))
            }
        }
        .alert(NSLocalizedString("Purchase Failed", comment: "purchase failed alert title"), isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button(NSLocalizedString("OK", comment: "dismiss alert button")) { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: - Coming Soon Banner

    private var comingSoonBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title2)
                .foregroundColor(QuantumColors.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("data_market_preview_mode", comment: ""))
                    .font(.headline)
                    .foregroundColor(QuantumColors.warning)
                Text(NSLocalizedString("data_market_beta_banner", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(QuantumColors.warning.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "cart.fill")
                    .font(.system(size: 36))
                    .foregroundColor(QuantumColors.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("data_market", comment: ""))
                        .font(QuantumFonts.headerTitle)
                        .foregroundColor(QuantumColors.textPrimary)
                    Text(String(format: NSLocalizedString("market_listings_count_format", comment: ""), "\(manager.marketplace.count)"))
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(LocalizedStringKey("Balance"))
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textTertiary)
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.caption2)
                            .foregroundColor(QuantumColors.accent)
                        Text(LocalizedStringKey("\(Int(computeStore.balance))"))
                            .font(QuantumFonts.body.weight(.bold))
                            .foregroundColor(QuantumColors.accent)
                    }
                }
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(MarketTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(QuantumColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(QuantumColors.accent.opacity(0.2), lineWidth: 1)
        )
    }

    private func tabButton(_ tab: MarketTab) -> some View {
        let isSelected = selectedTab == tab
        let fgColor: Color = isSelected ? QuantumColors.background : QuantumColors.textSecondary
        let bgShape: AnyView = isSelected
            ? AnyView(RoundedRectangle(cornerRadius: 8).fill(QuantumColors.accent))
            : AnyView(Color.clear)

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        }) {
            Text(NSLocalizedString(tab.rawValue, comment: "data market tab name"))
                .font(QuantumFonts.body.weight(.semibold))
                .foregroundColor(fgColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(bgShape)
        }
        .accessibilityLabel(String(format: NSLocalizedString("market_switch_tab", comment: "Accessibility label for switching market tab"), tab.rawValue))
    }

    // MARK: - Create Listing Form

    private var createListingSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCreateForm.toggle()
                }
            }) {
                HStack {
                    Image(systemName: showCreateForm ? "chevron.down" : "plus.circle.fill")
                        .foregroundColor(QuantumColors.accent)
                    Text(NSLocalizedString("create_listing", comment: ""))
                        .font(QuantumFonts.sectionHeader)
                        .foregroundColor(QuantumColors.textPrimary)
                    Spacer()
                }
            }
            .accessibilityLabel(NSLocalizedString("market_toggle_create_form", comment: "Accessibility label for toggling create listing form"))

            if showCreateForm {
                VStack(spacing: 12) {
                    TextField(NSLocalizedString("market_listing_title_placeholder", comment: "Placeholder for listing title input"), text: $newTitle)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(QuantumColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(QuantumColors.accent.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(QuantumColors.textPrimary)
                        .accessibilityLabel(NSLocalizedString("market_listing_title_input", comment: "Accessibility label for listing title input field"))

                    TextField(NSLocalizedString("market_listing_description_placeholder", comment: "Placeholder for listing description input"), text: $newDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(QuantumColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(QuantumColors.accent.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(QuantumColors.textPrimary)
                        .accessibilityLabel(NSLocalizedString("market_listing_description_input", comment: "Accessibility label for listing description input field"))

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("price_tokens", comment: ""))
                                .font(QuantumFonts.caption)
                                .foregroundColor(QuantumColors.textSecondary)
                            TextField("0.0", value: $newPrice, format: .number)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(QuantumColors.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(QuantumColors.accent.opacity(0.3), lineWidth: 1)
                                )
                                .foregroundColor(QuantumColors.textPrimary)
                                .accessibilityLabel(NSLocalizedString("market_listing_price_input", comment: "Accessibility label for listing price input field"))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("data_market_category_label", comment: "Category label"))
                                .font(QuantumFonts.caption)
                                .foregroundColor(QuantumColors.textSecondary)
                            Picker(NSLocalizedString("data_market_category_picker", comment: "Category picker label"), selection: $newCategory) {
                                ForEach(DataCategory.allCases, id: \.self) { cat in
                                    Text(localizedCategory(cat)).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(QuantumColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(QuantumColors.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(QuantumColors.accent.opacity(0.3), lineWidth: 1)
                            )
                            .accessibilityLabel(NSLocalizedString("market_listing_category_picker", comment: "Accessibility label for listing category picker"))
                        }
                    }

                    Button(action: createListing) {
                        HStack {
                            Image(systemName: "arrow.up.doc.fill")
                            Text(NSLocalizedString("publish_listing", comment: ""))
                        }
                        .font(QuantumFonts.body.weight(.semibold))
                        .foregroundColor(QuantumColors.background)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(canCreateListing ? QuantumColors.accent : QuantumColors.accent.opacity(0.3))
                        )
                    }
                    .disabled(!canCreateListing)
                    .accessibilityLabel(NSLocalizedString("market_publish_new_listing", comment: "Accessibility label for publish new listing button"))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    private var canCreateListing: Bool {
        !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !newDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        newPrice > 0
    }

    private func createListing() {
        let listing = manager.createListing(
            title: newTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            description: newDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            category: newCategory,
            price: newPrice
        )
        manager.marketplace.insert(listing, at: 0)
        newTitle = ""
        newDescription = ""
        newPrice = 0
        newCategory = .browsingHistory
        withAnimation(.easeInOut(duration: 0.2)) {
            showCreateForm = false
        }
    }

    // MARK: - Listings Section

    private var listingsSection: some View {
        VStack(spacing: 12) {
            switch selectedTab {
            case .marketplace:
                marketplaceList
            case .myListings:
                myListingsList
            }
        }
    }

    private var marketplaceList: some View {
        VStack(spacing: 12) {
            if manager.marketplace.isEmpty {
                emptyState(icon: "cart", message: NSLocalizedString("No listings available", comment: "empty marketplace state"))
            } else {
                ForEach(manager.marketplace.filter { $0.status == .active }) { listing in
                    marketplaceCard(listing)
                }
            }
        }
    }

    private var myListingsList: some View {
        VStack(spacing: 12) {
            if manager.myListings.isEmpty {
                emptyState(icon: "doc.text", message: NSLocalizedString("You haven't created any listings", comment: "empty my listings state"))
            } else {
                ForEach(manager.myListings) { listing in
                    myListingCard(listing)
                }
            }
        }
    }

    // MARK: - Marketplace Card

    private func marketplaceCard(_ listing: DataListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: listing.category.icon)
                    .font(.system(size: 20))
                    .foregroundColor(QuantumColors.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(QuantumColors.accent.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.title)
                        .font(QuantumFonts.body.weight(.semibold))
                        .foregroundColor(QuantumColors.textPrimary)
                    Text(localizedCategory(listing.category))
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.caption2)
                    Text(String(format: "%.1f", listing.price))
                        .font(QuantumFonts.body.weight(.bold))
                }
                .foregroundColor(QuantumColors.accentWarm)
            }

            Text(listing.description)
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textSecondary)
                .lineLimit(2)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text(String(format: NSLocalizedString("market_buyers_count_format", comment: ""), "\(listing.buyerCount)"))
                        .font(QuantumFonts.caption)
                }
                .foregroundColor(QuantumColors.textTertiary)

                Spacer()

                if isAlreadyPurchased(listing) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text(LocalizedStringKey("Purchased"))
                            .font(QuantumFonts.caption)
                    }
                    .foregroundColor(QuantumColors.success)
                } else {
                    Button(action: {
                        listingToPurchase = listing
                        showPurchaseConfirm = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "cart.badge.plus")
                                .font(.caption2)
                            Text(LocalizedStringKey("Buy"))
                                .font(QuantumFonts.caption.weight(.semibold))
                        }
                        .foregroundColor(QuantumColors.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(QuantumColors.accent, lineWidth: 1)
                        )
                    }
                    .accessibilityLabel(String(format: NSLocalizedString("market_buy_listing", comment: "Accessibility label for buy listing button"), listing.title, String(format: "%.1f", listing.price)))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(QuantumColors.surface.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(QuantumColors.accent.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - My Listing Card

    private func myListingCard(_ listing: DataListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: listing.category.icon)
                    .font(.system(size: 20))
                    .foregroundColor(QuantumColors.accentSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(QuantumColors.accentSecondary.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.title)
                        .font(QuantumFonts.body.weight(.semibold))
                        .foregroundColor(QuantumColors.textPrimary)
                    Text(localizedStatus(listing.status))
                        .font(QuantumFonts.caption)
                        .foregroundColor(statusColor(listing.status))
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.caption2)
                    Text(String(format: "%.1f", listing.price))
                        .font(QuantumFonts.body.weight(.bold))
                }
                .foregroundColor(QuantumColors.accentWarm)
            }

            Text(listing.description)
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textSecondary)
                .lineLimit(2)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text(String(format: NSLocalizedString("market_buyers_count_format", comment: ""), "\(listing.buyerCount)"))
                        .font(QuantumFonts.caption)
                }
                .foregroundColor(QuantumColors.textTertiary)

                Spacer()

                Button(action: {
                    manager.revokeListing(listing.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.caption2)
                        Text(NSLocalizedString("remove_listing", comment: ""))
                            .font(QuantumFonts.caption.weight(.semibold))
                    }
                    .foregroundColor(QuantumColors.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(QuantumColors.error.opacity(0.5), lineWidth: 1)
                    )
                }
                .accessibilityLabel(String(format: NSLocalizedString("market_remove_listing", comment: "Accessibility label for remove listing button"), listing.title))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(QuantumColors.surface.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(QuantumColors.accentSecondary.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(QuantumColors.textTertiary)
            Text(message)
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func isAlreadyPurchased(_ listing: DataListing) -> Bool {
        manager.purchases.contains { $0.listingId == listing.id }
    }

    private func executePurchase(_ listing: DataListing) {
        guard computeStore.balance >= listing.price else {
            purchaseError = String(format: NSLocalizedString("popopx_market_insufficient_balance", comment: "insufficient balance error"), String(format: "%.1f", listing.price), String(format: "%.1f", computeStore.balance))
            listingToPurchase = nil
            return
        }
        let purchased = manager.purchaseListing(listing)
        if purchased {
            let debited = computeStore.debit(listing.price)
            if !debited {
                // Should not happen if balance was checked beforehand, but refund the listing if it does
                logger.error("executePurchase: debit failed after successful purchase, tokens may be inconsistent")
            }
        } else {
            purchaseError = NSLocalizedString("popopx_market_purchase_failed", comment: "purchase failed error message")
        }
        listingToPurchase = nil
    }

    private func statusColor(_ status: DataListing.ListingStatus) -> Color {
        switch status {
        case .active: return QuantumColors.success
        case .sold: return QuantumColors.accent
        case .expired: return QuantumColors.textTertiary
        case .revoked: return QuantumColors.error
        }
    }

    private func localizedStatus(_ status: DataListing.ListingStatus) -> String {
        switch status {
        case .active: return NSLocalizedString("data_market_status_active", comment: "")
        case .sold: return NSLocalizedString("data_market_status_sold", comment: "")
        case .expired: return NSLocalizedString("data_market_status_expired", comment: "")
        case .revoked: return NSLocalizedString("data_market_status_revoked", comment: "")
        }
    }

    private func localizedCategory(_ cat: DataCategory) -> String {
        switch cat {
        case .browsingHistory: return NSLocalizedString("data_market_cat_browsing", comment: "")
        case .appUsage: return NSLocalizedString("data_market_cat_app_usage", comment: "")
        case .locationData: return NSLocalizedString("data_market_cat_location", comment: "")
        case .preferences: return NSLocalizedString("data_market_cat_preferences", comment: "")
        case .healthMetrics: return NSLocalizedString("data_market_cat_health", comment: "")
        case .socialGraph: return NSLocalizedString("data_market_cat_social", comment: "")
        }
    }
}
