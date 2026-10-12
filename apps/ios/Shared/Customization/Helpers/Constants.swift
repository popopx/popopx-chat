// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/helpers
import Foundation

enum ServerConfig {
    static var baseURL: String {
        ServerAPI.backendURL
    }

    static var apiVersion: String { "v1" }

    static func url(for endpoint: String) -> URL? {
        URL(string: "\(baseURL)/api/\(apiVersion)/\(endpoint)")
    }
}

enum Constants {
    static let appGroupIdentifier = "group.com.popopxchat.popopx"
    static let keychainDatabasePassword = "kcDatabasePassword"
    static let keychainAppPassword = "kcAppPassword"

    static let trialDurationDays = 3
    static let giftExpiryHours = 24

    static let subscriptionProductBasicMonthly = "com.popopxchat.popopx.basic.monthly"
    static let subscriptionProductBasicYearly = "com.popopxchat.popopx.basic.yearly"
    static let subscriptionProductPremiumMonthly = "com.popopxchat.popopx.premium.monthly"
    static let subscriptionProductPremiumYearly = "com.popopxchat.popopx.premium.yearly"

    static let allSubscriptionProductIds = [
        subscriptionProductBasicMonthly, subscriptionProductBasicYearly,
        subscriptionProductPremiumMonthly, subscriptionProductPremiumYearly
    ]

    static let tokenProductStarter = "com.popopxchat.popopx.tokens.starter"
    static let tokenProductPlus = "com.popopxchat.popopx.tokens.plus"
    static let tokenProductPro = "com.popopxchat.popopx.tokens.pro"
    static let tokenProductQuantum = "com.popopxchat.popopx.tokens.quantum"
}

enum Branding {
    static let appName = "POPOPX Chat"
    static let appShortName = "POPOPX"
    static let bundleDisplayName = "POPOPX"

    static let originalCredit = "SimpleX Chat"
    static let originalCopyright = "Copyright © 2025 POPOPX."
    static let originalRepo = "https://github.com/simplex-chat/simplex-chat"
    static let originalWebsite = "https://simplex.chat"
    static let licenseURL = "https://www.gnu.org/licenses/agpl-3.0.html"

    static let bitchatCredit = "bitchat by Jack Dorsey & permissionless.tech"
    static let bitchatRepo = "https://github.com/permissionlesstech/bitchat"
    static let bitchatLicense = "https://unlicense.org"
    static let bitchatLicenseName = "The Unlicense (Public Domain)"

    static let clientSourceRepo = "https://github.com/popopx/popopx-ios"
    static let serverSourceRepo = "https://github.com/popopx/popopx-chat"

    static let lockName = "POPOPX Lock"
    static let addressName = "POPOPX Address"
    static let quantumName = "POPOPX Quantum"
}
