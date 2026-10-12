//
//  RTCModels.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 03/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import POPOPXSwitch
import WebRTC

func parseRTCIceServer(_ str: String) -> POPOPXSwitch.RTCIceServer? {
    var s = replaceScheme(str, "stun:")
    s = replaceScheme(s, "stuns:")
    s = replaceScheme(s, "turn:")
    s = replaceScheme(s, "turns:")
    if let u: URL = URL(string: s),
       let scheme = u.scheme,
       let host = u.host,
       let port = u.port,
       u.path == "" && (scheme == "stun" || scheme == "stuns" || scheme == "turn" || scheme == "turns")  {
        let query = u.query == nil || u.query == "" ? "" : "?" + (u.query ?? "")
        return POPOPXSwitch.RTCIceServer(
            urls: ["\(scheme):\(host):\(port)\(query)"],
            username: u.user,
            credential: u.password
        )
    }
    return nil
}

private func replaceScheme(_ s: String, _ scheme: String) -> String {
    s.starts(with: scheme)
    ? s.replacingOccurrences(of: scheme, with: scheme + "//", options: .anchored, range: nil)
    : s
}

func parseRTCIceServers(_ servers: [String]) -> [POPOPXSwitch.RTCIceServer]? {
    var iceServers: [POPOPXSwitch.RTCIceServer] = []
    for s in servers {
        if let server = parseRTCIceServer(s) {
            iceServers.append(server)
        } else {
            return nil
        }
    }
    return iceServers.isEmpty ? nil : iceServers
}

func getIceServers() -> [POPOPXSwitch.RTCIceServer]? {
    if let servers = UserDefaults.standard.stringArray(forKey: DEFAULT_WEBRTC_ICE_SERVERS) {
        return parseRTCIceServers(servers)
    }
    return nil
}

func getWebRTCIceServers() -> [WebRTC.RTCIceServer]? {
    if let servers = UserDefaults.standard.stringArray(forKey: DEFAULT_WEBRTC_ICE_SERVERS) {
        return parseRTCIceServers(servers)?.toWebRTCIceServers()
    }
    return nil
}

// MARK: - POPOPX
fileprivate let _pxBrandRTCModels = "PX_RTC_MODELS"
