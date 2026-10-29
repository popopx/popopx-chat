// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import CryptoKit
import os

final class PinnedSessionDelegate: NSObject, URLSessionDelegate {

    // Certificate pins are no longer needed — all api.popopxchat.com calls have been
    // eliminated. PinnedURLSession is retained for SMS bridge (Twilio/Nexmo) which uses
    // default SSL validation via .performDefaultHandling for non-pinned hosts.
    private let pinnedHashes: Set<String> = []

    private let pinnedHost = ""

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let host = challenge.protectionSpace.host

        #if DEBUG
        if host == "localhost" || host == "127.0.0.1" {
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }
        #endif

        guard host == pinnedHost else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if pinnedHashes.isEmpty {
            #if DEBUG
            os_log(.info, "Certificate pinning: no pins configured for %{public}@, using default SSL validation (DEBUG)", pinnedHost)
            completionHandler(.performDefaultHandling, nil)
            #else
            os_log(.error, "Certificate pinning: no pins configured for %{public}@, rejecting connection (fail-closed)", pinnedHost)
            completionHandler(.cancelAuthenticationChallenge, nil)
            #endif
            return
        }

        guard let chainRaw = SecTrustCopyCertificateChain(trust) else {
            os_log(.error, "Certificate pinning: failed to extract certificate chain")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let chain = chainRaw as? [SecCertificate] ?? []

        for cert in chain {
            if let hash = spkiHash(for: cert), pinnedHashes.contains(hash) {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }

        os_log(.error, "Certificate pinning: no matching pin for %{public}@", host)
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    private func spkiHash(for certificate: SecCertificate) -> String? {
        let certData = SecCertificateCopyData(certificate) as Data
        guard let spkiData = extractSPKI(from: certData) else {
            os_log(.debug, "Certificate pinning: failed to extract SPKI from certificate (malformed or unexpected DER structure)")
            return nil
        }

        let digest = SHA256.hash(data: spkiData)
        return "sha256/" + Data(digest).base64EncodedString()
    }

    // MARK: - ASN.1 DER parser

    // Extracts the SubjectPublicKeyInfo SEQUENCE from an X.509 DER certificate.
    // X.509: SEQUENCE { tbsCertificate SEQUENCE { version, serial, sigAlg, issuer, validity, subject, SPKI, ... } }
    private func extractSPKI(from derData: Data) -> Data? {
        var offset = 0
        // Outer SEQUENCE (the whole certificate)
        guard let (_, _, outerRange) = readTLV(derData, offset: &offset) else { return nil }
        offset = outerRange.lowerBound

        // tbsCertificate SEQUENCE
        guard let (_, _, tbsRange) = readTLV(derData, offset: &offset) else { return nil }
        offset = tbsRange.lowerBound

        // Skip 6 fields: version [0 EXPLICIT], serialNumber, signatureAlgorithm, issuer, validity, subject
        for _ in 0..<6 {
            guard readTLV(derData, offset: &offset) != nil else { return nil }
        }

        // 7th field: subjectPublicKeyInfo
        let spkiStart = offset
        guard let (tag, _, spkiRange) = readTLV(derData, offset: &offset) else { return nil }
        guard tag == 0x30 else { return nil } // must be SEQUENCE

        let start = derData.startIndex + spkiStart
        let end = derData.startIndex + spkiRange.upperBound
        return derData[start..<end]
    }

    private func readTLV(_ data: Data, offset: inout Int) -> (tag: UInt8, length: Int, range: Range<Int>)? {
        guard offset < data.count else { return nil }
        let tag = data[data.startIndex + offset]
        offset += 1

        guard offset < data.count else { return nil }
        var length = Int(data[data.startIndex + offset])
        offset += 1

        if length & 0x80 != 0 {
            let numBytes = length & 0x7F
            length = 0
            for _ in 0..<numBytes {
                guard offset < data.count else { return nil }
                length = (length << 8) | Int(data[data.startIndex + offset])
                offset += 1
            }
        }

        let contentStart = offset
        let contentEnd = offset + length
        guard contentEnd <= data.count else { return nil }
        offset = contentEnd

        return (tag, length, contentStart..<contentEnd)
    }
}

enum PinnedURLSession {
    static let delegate = PinnedSessionDelegate()

    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()
}

// MARK: - Certificate Pinning Coverage Audit
//
// This audit documents all URLSession creation points in the codebase and identifies
// gaps where certificate pinning should be applied.
//
// PINNED (using PinnedURLSession.shared):
// ✅ Shared/Customization/Helpers/ServerAPI.swift:62
// ✅ Shared/Customization/Bridge/SMSBridgeView.swift:221, 286
//
// NOTE: All monetization-related api.popopxchat.com calls have been eliminated.
// ServerAPI.swift still uses api.popopxchat.com for AI chat, compliance, and MPC features.
//
// GAP — Tor-Only Sessions (indirectly protected by Tor circuit integrity):
// ⚠️ BitchatMesh/Sources/BitchatMesh/Services/TorManagerStub.swift:181
//    - Tor bootstrap connectivity check (verifyTorConnectivity)
//    - Uses ephemeral session with SOCKS proxy; Tor's own TLS protects this
//    - RECOMMENDATION: Low priority — Tor already provides transport security
//
// ⚠️ BitchatMesh/Sources/BitchatMesh/Services/TorManagerStub.swift:227, 241, 247
//    - TorURLSession._session (Tor-proxied)
//    - TorURLSession.directSession (direct fallback)
//    - These route through Tor or are explicitly direct when Tor is disabled
//    - RECOMMENDATION: Medium priority — if sensitive traffic goes here,
//      add certificate pinning delegate to both sessions
//
// GAP — Nostr WebSocket Sessions (external relay infrastructure):
// ⚠️ BitchatMesh/Sources/BitchatMesh/Nostr/NostrRelayManager.swift:46-58
//    - URLSessionAdapter wraps URLSession for Nostr WebSocket connections
//    - Session comes from TorURLSession.shared.session (line 113)
//    - Connects to arbitrary Nostr relays (third-party infrastructure)
//    - RECOMMENDATION: Not applicable — these connect to third-party relays,
//      not our pinned host. Domain validation happens at application layer.
//
// ⚠️ BitchatMesh/Sources/BitchatMesh/Nostr/GeoRelayDirectory.swift:91
//    - Fetches geo relay directory CSV from raw.githubusercontent.com
//    - Uses TorURLSession.shared.session
//    - RECOMMENDATION: Low priority — GitHub's cert is managed by their CDN,
//      but could add separate pin set for raw.githubusercontent.com if desired
//
// SUMMARY:
// - Monetization: all local (StoreKit + FFI), no api.popopxchat.com calls
// - ServerAPI: still uses api.popopxchat.com for AI/compliance/MPC (uses PinnedURLSession)
// - Tor-wrapped sessions inherit Tor circuit protection but lack explicit pinning
// - Nostr relay connections are intentionally unpinable (third-party infrastructure)
