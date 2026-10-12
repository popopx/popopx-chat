// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  PXLinkEncryption.swift
//  POPOPX (iOS)
//
//  Client-side AES-256-GCM encryption for connection links.
//  Matches the Haskell-side encryptConnFullLink in LinkEncryption.hs.
//  Payload format: key(32) + nonce(12) + tag(16) + ciphertext, base64url-encoded.
//

import Foundation
import CryptoKit

func encryptConnLinkText(_ plainText: String) -> String? {
    let prefix = "popopx://enc#"

    guard let plaintextData = plainText.data(using: .utf8) else { return nil }

    let key = SymmetricKey(size: .bits256)
    let keyData = key.withUnsafeBytes { Data($0) }

    do {
        let sealedBox = try AES.GCM.seal(plaintextData, using: key)
        guard let combined = sealedBox.combined else { return nil }

        let nonceLen = 12
        let tagLen = 16
        let ciphertextLen = combined.count - nonceLen - tagLen
        guard ciphertextLen > 0 else { return nil }

        let nonce = combined.prefix(nonceLen)
        let ciphertext = combined.dropFirst(nonceLen).prefix(ciphertextLen)
        let tag = combined.suffix(tagLen)

        var payload = Data()
        payload.append(keyData)
        payload.append(nonce)
        payload.append(tag)
        payload.append(ciphertext)

        let encoded = payload.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return prefix + encoded
    } catch {
        return nil
    }
}
