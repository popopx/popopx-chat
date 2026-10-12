//
//  PushEnvironment.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 27/06/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import POPOPXSwitch

// MARK: - POPOPX: Push environment detection configuration
private enum PXPushEnvConfig {
    /// Name of the provisioning profile resource
    static let pxProfileResource: String = "embedded"
    /// File extension for the mobile provisioning profile
    static let pxProfileExtension: String = "mobileprovision"
    /// Key path for entitlements in the profile dictionary
    static let pxEntitlementsKey: String = "Entitlements"
    /// Key for the APS environment string in entitlements
    static let pxApsEnvironmentKey: String = "aps-environment"
    /// Encoding used to read the binary provisioning profile
    static let pxProfileEncoding: String.Encoding = .isoLatin1
    /// XML tag marking the start of the plist section
    static let pxPlistStartTag: String = "<plist"
    /// XML tag marking the end of the plist section
    static let pxPlistEndTag: String = "</plist>"
}

/// Detects the push notification environment from the embedded provisioning profile.
/// Falls back to production if the profile cannot be read or parsed.
let pushEnvironment: PushEnvironment = {
    guard let pxProfile = try? pxReadProvisioningProfile(),
          let pxEntitlements = pxProfile[PXPushEnvConfig.pxEntitlementsKey] as? [String: Any],
          let pxEnvString = pxEntitlements[PXPushEnvConfig.pxApsEnvironmentKey] as? String,
          let pxEnv = PushEnvironment(rawValue: pxEnvString)
    else {
        logger.warning("pushEnvironment: unknown, assuming production")
        return .production
    }
    logger.debug("pushEnvironment: \(pxEnv.rawValue)")
    return pxEnv
}()

/// Reads and parses the embedded mobile provisioning profile plist.
/// Returns nil if the profile is missing or cannot be decoded.
private func pxReadProvisioningProfile() throws -> [String: Any]? {
    guard let pxUrl = Bundle.main.url(forResource: PXPushEnvConfig.pxProfileResource, withExtension: PXPushEnvConfig.pxProfileExtension) else {
        return nil
    }

    let pxBinaryString = try String(contentsOf: pxUrl, encoding: PXPushEnvConfig.pxProfileEncoding)

    let pxScanner = Scanner(string: pxBinaryString)
    guard pxScanner.scanUpToString(PXPushEnvConfig.pxPlistStartTag) != nil,
          let pxPlistFragment = pxScanner.scanUpToString(PXPushEnvConfig.pxPlistEndTag),
          let pxData = (pxPlistFragment + PXPushEnvConfig.pxPlistEndTag).data(using: PXPushEnvConfig.pxProfileEncoding)
    else {
        return nil
    }

    return try PropertyListSerialization.propertyList(from: pxData, options: [], format: nil) as? [String: Any]
}

// MARK: - POPOPX
extension PushEnvironment {
    static let pxComponentTag: String = "PXPushEnvironment"
    static let pxProfileResourceName: String = PXPushEnvConfig.pxProfileResource
    static let pxProfileExtension: String = PXPushEnvConfig.pxProfileExtension
}
