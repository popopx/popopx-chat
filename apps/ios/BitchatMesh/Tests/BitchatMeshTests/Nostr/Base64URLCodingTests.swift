// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import Testing
@testable import BitchatMesh

struct Base64URLCodingTests {
    @Test
    func encodesWithoutPaddingOrURLUnsafeCharacters() {
        let encoded = Base64URLCoding.encode(Data([0xff, 0xee, 0xdd, 0xcc]))

        #expect(!encoded.contains("="))
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
    }

    @Test
    func decodesUnpaddedValue() throws {
        let data = try #require(Base64URLCoding.decode("_-7dzA"))

        #expect(data == Data([0xff, 0xee, 0xdd, 0xcc]))
    }

    @Test
    func roundTripsData() throws {
        let original = Data("hello bitchat".utf8)

        let decoded = try #require(Base64URLCoding.decode(Base64URLCoding.encode(original)))

        #expect(decoded == original)
    }
}
