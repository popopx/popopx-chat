// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation

/// A mesh peer contact for integration into POPOPX's ChatInfo system.
public struct MeshPeerContact: Identifiable, Hashable, Codable {
    public let peerIDHex: String
    public var nickname: String
    public var isConnected: Bool

    public init(peerIDHex: String, nickname: String, isConnected: Bool) {
        self.peerIDHex = peerIDHex
        self.nickname = nickname
        self.isConnected = isConnected
    }

    public var id: String { "mesh:\(peerIDHex)" }
}

extension MeshPeerContact: NamedChat {
    public var displayName: String { nickname }
    public var fullName: String { nickname }
    public var shortDescr: String? { nil }
    public var image: String? { nil }
    public var localAlias: String { "" }
}
