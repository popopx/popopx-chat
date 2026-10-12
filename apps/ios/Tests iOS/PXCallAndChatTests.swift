//
//  PXCallAndChatTests.swift
//  Tests iOS
//
//  Unit tests for P4 extracted types:
//  PXCallModel, PXWebRTCProtocol, PXMergedChatItems
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import XCTest
@testable import POPOPX
@testable import POPOPXSwitch

final class PXCallModelTests: XCTestCase {

    // MARK: - CallMediaSources

    func testHasVideoFalseWhenNoSources() {
        let sources = CallMediaSources()
        XCTAssertFalse(sources.hasVideo)
    }

    func testHasVideoTrueWhenCameraEnabled() {
        let sources = CallMediaSources(mic: false, camera: true)
        XCTAssertTrue(sources.hasVideo)
    }

    func testHasVideoTrueWhenScreenVideoEnabled() {
        var sources = CallMediaSources()
        sources.screenVideo = true
        XCTAssertTrue(sources.hasVideo)
    }

    func testHasVideoTrueWhenBothEnabled() {
        let sources = CallMediaSources(mic: true, camera: true, screenAudio: true, screenVideo: true)
        XCTAssertTrue(sources.hasVideo)
    }

    func testCallMediaSourcesCodableRoundtrip() throws {
        let original = CallMediaSources(mic: true, camera: false, screenAudio: true, screenVideo: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CallMediaSources.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCallMediaSourcesDefaultValues() {
        let sources = CallMediaSources()
        XCTAssertFalse(sources.mic)
        XCTAssertFalse(sources.camera)
        XCTAssertFalse(sources.screenAudio)
        XCTAssertFalse(sources.screenVideo)
    }

    // MARK: - CallState

    func testCallStateTextNonEmpty() {
        let states: [CallState] = [
            .waitCapabilities, .invitationSent, .invitationAccepted,
            .offerSent, .offerReceived, .answerReceived,
            .negotiated, .connected, .ended
        ]
        for state in states {
            let text = state.text
            let str = String(describing: text)
            XCTAssertFalse(str.isEmpty, "CallState.\(state) should have non-empty text")
        }
    }

    // MARK: - CallDirection

    func testCallDirectionCases() {
        let incoming = CallDirection.incoming
        let outgoing = CallDirection.outgoing
        XCTAssertNotEqual(String(describing: incoming), String(describing: outgoing))
    }
}

final class PXWebRTCProtocolTests: XCTestCase {

    // MARK: - WCallCommand.cmdType

    func testCmdTypeCapabilities() {
        let cmd = WCallCommand.capabilities(media: .audio)
        XCTAssertEqual(cmd.cmdType, "capabilities")
    }

    func testCmdTypeStart() {
        let cmd = WCallCommand.start(media: .video)
        XCTAssertEqual(cmd.cmdType, "start")
    }

    func testCmdTypeOffer() {
        let cmd = WCallCommand.offer(offer: "sdp", iceCandidates: "candidates", media: .video)
        XCTAssertEqual(cmd.cmdType, "offer")
    }

    func testCmdTypeAnswer() {
        let cmd = WCallCommand.answer(answer: "sdp", iceCandidates: "candidates")
        XCTAssertEqual(cmd.cmdType, "answer")
    }

    func testCmdTypeIce() {
        let cmd = WCallCommand.ice(iceCandidates: "candidate:1")
        XCTAssertEqual(cmd.cmdType, "ice")
    }

    func testCmdTypeMedia() {
        let cmd = WCallCommand.media(source: .mic, enable: true)
        XCTAssertEqual(cmd.cmdType, "media")
    }

    func testCmdTypeEnd() {
        let cmd = WCallCommand.end
        XCTAssertEqual(cmd.cmdType, "end")
    }

    // MARK: - WCallCommand encode/decode roundtrip

    func testCapabilitiesRoundtrip() throws {
        let original = WCallCommand.capabilities(media: .video)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WCallCommand.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testStartRoundtrip() throws {
        let original = WCallCommand.start(media: .audio, aesKey: "key123", iceServers: nil, relay: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WCallCommand.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testOfferRoundtrip() throws {
        let original = WCallCommand.offer(
            offer: "v=0\r\no=-",
            iceCandidates: "candidate:1 1 udp 2130706431 192.168.1.1 8998 typ host",
            media: .video,
            aesKey: "shared-key",
            iceServers: [RTCIceServer(urls: ["stun:stun.example.com"], username: "user", credential: "pass")],
            relay: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WCallCommand.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAnswerRoundtrip() throws {
        let original = WCallCommand.answer(answer: "v=0\r\no=-", iceCandidates: "candidate:2")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WCallCommand.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testIceRoundtrip() throws {
        let original = WCallCommand.ice(iceCandidates: "candidate:3 1 tcp 1234 10.0.0.1 5000 typ relay")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WCallCommand.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testMediaRoundtrip() throws {
        let original = WCallCommand.media(source: .camera, enable: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WCallCommand.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEndRoundtrip() throws {
        let original = WCallCommand.end
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WCallCommand.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - WCallResponse decode

    func testDecodeOkResponse() throws {
        let json = #"{"type":"ok"}"#
        let resp = try JSONDecoder().decode(WCallResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(resp, .ok)
        XCTAssertEqual(resp.respType, "ok")
    }

    func testDecodeEndedResponse() throws {
        let json = #"{"type":"ended"}"#
        let resp = try JSONDecoder().decode(WCallResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(resp, .ended)
        XCTAssertEqual(resp.respType, "ended")
    }

    func testDecodeErrorResponse() throws {
        let json = #"{"type":"error","message":"peer disconnected"}"#
        let resp = try JSONDecoder().decode(WCallResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(resp, .error(message: "peer disconnected"))
        XCTAssertEqual(resp.respType, "error")
    }

    func testDecodeAnswerResponse() throws {
        let json = #"{"type":"answer","answer":"v=0","iceCandidates":"candidate:1"}"#
        let resp = try JSONDecoder().decode(WCallResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(resp, .answer(answer: "v=0", iceCandidates: "candidate:1"))
    }

    func testDecodeIceResponse() throws {
        let json = #"{"type":"ice","iceCandidates":"candidate:5"}"#
        let resp = try JSONDecoder().decode(WCallResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(resp, .ice(iceCandidates: "candidate:5"))
    }

    func testDecodeInvalidTypeReturnsInvalid() throws {
        let json = #"{"type":"unknown_future_type"}"#
        let resp = try JSONDecoder().decode(WCallResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(resp, .invalid(type: "unknown_future_type"))
        XCTAssertEqual(resp.respType, "invalid")
    }

    func testDecodeMalformedJSONReturnsInvalid() throws {
        let json = #"{"not_valid": true}"#
        let resp = try JSONDecoder().decode(WCallResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(resp, .invalid(type: "unknown"))
    }

    // MARK: - WCallResponse.respType

    func testRespTypeAllCases() {
        let cases: [(WCallResponse, String)] = [
            (.ok, "ok"),
            (.ended, "ended"),
            (.error(message: "x"), "error"),
            (.answer(answer: "a", iceCandidates: "b"), "answer"),
            (.ice(iceCandidates: "c"), "ice"),
            (.invalid(type: "z"), "invalid"),
        ]
        for (resp, expected) in cases {
            XCTAssertEqual(resp.respType, expected)
        }
    }

    // MARK: - WVAPICall encode

    func testWVAPICallEncodesWithType() throws {
        let call = WVAPICall(corrId: 42, command: .end)
        let data = try JSONEncoder().encode(call)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["corrId"] as? Int, 42)
        XCTAssertNotNil(dict?["command"])
    }

    // MARK: - WVAPIMessage roundtrip

    func testWVAPIMessageRoundtrip() throws {
        let original = WVAPIMessage(corrId: 7, resp: .ok, command: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WVAPIMessage.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

final class PXMergedChatItemsTests: XCTestCase {

    private func makeItem(_ id: Int64, text: String = "msg", status: CIStatus = .sndNew) -> ChatItem {
        ChatItem.getSample(id, .directSnd, Date(), text, status)
    }

    // MARK: - MergedItem.single

    func testSingleItemId() {
        let chatItem = makeItem(100)
        let listItem = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 0)
        let merged = MergedItem.single(item: listItem, startIndexInReversedItems: 5, hash: "h1")
        XCTAssertEqual(merged.id, 100)
    }

    func testSingleItemNewestAndOldest() {
        let chatItem = makeItem(200)
        let listItem = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 0)
        let merged = MergedItem.single(item: listItem, startIndexInReversedItems: 3, hash: "h2")
        XCTAssertEqual(merged.newest().item.id, 200)
        XCTAssertEqual(merged.oldest().item.id, 200)
    }

    func testSingleItemHasUnreadWhenNew() {
        let chatItem = makeItem(300, status: .rcvNew)
        let listItem = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 2)
        let merged = MergedItem.single(item: listItem, startIndexInReversedItems: 0, hash: "h3")
        XCTAssertTrue(merged.hasUnread())
    }

    func testSingleItemHasNoUnreadWhenSent() {
        let chatItem = makeItem(301, status: .sndNew)
        let listItem = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 0)
        let merged = MergedItem.single(item: listItem, startIndexInReversedItems: 0, hash: "h4")
        XCTAssertFalse(merged.hasUnread())
    }

    func testSingleItemLastIndexInReversed() {
        let chatItem = makeItem(400)
        let listItem = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 0)
        let merged = MergedItem.single(item: listItem, startIndexInReversedItems: 7, hash: "h5")
        XCTAssertEqual(merged.lastIndexInReversed(), 7)
    }

    func testSingleItemStartIndex() {
        let chatItem = makeItem(500)
        let listItem = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 0)
        let merged = MergedItem.single(item: listItem, startIndexInReversedItems: 12, hash: "h6")
        XCTAssertEqual(merged.startIndexInReversedItems, 12)
    }

    // MARK: - MergedItem.grouped

    func testGroupedItemId() {
        let chatItem = makeItem(600)
        let listItem = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 0)
        let merged = MergedItem.grouped(
            items: BoxedValue([listItem]),
            revealed: false,
            revealedIdsWithinGroup: BoxedValue([]),
            rangeInReversed: BoxedValue(0...0),
            mergeCategory: .memberConnected,
            unreadIds: BoxedValue(Set()),
            startIndexInReversedItems: 0,
            hash: "gh1"
        )
        XCTAssertEqual(merged.id, 600)
    }

    func testGroupedItemNewestIsFirst() {
        let item1 = makeItem(700)
        let item2 = makeItem(701)
        let li1 = ListItem(item: item1, prevItem: nil, nextItem: item2, unreadBefore: 0)
        let li2 = ListItem(item: item2, prevItem: item1, nextItem: nil, unreadBefore: 0)
        let merged = MergedItem.grouped(
            items: BoxedValue([li1, li2]),
            revealed: true,
            revealedIdsWithinGroup: BoxedValue([700, 701]),
            rangeInReversed: BoxedValue(0...1),
            mergeCategory: .rcvGroupEvent,
            unreadIds: BoxedValue(Set()),
            startIndexInReversedItems: 0,
            hash: "gh2"
        )
        XCTAssertEqual(merged.newest().item.id, 700)
        XCTAssertEqual(merged.oldest().item.id, 701)
    }

    func testGroupedItemHasUnread() {
        let chatItem = makeItem(800, status: .rcvNew)
        let listItem = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 1)
        let merged = MergedItem.grouped(
            items: BoxedValue([listItem]),
            revealed: false,
            revealedIdsWithinGroup: BoxedValue([]),
            rangeInReversed: BoxedValue(0...0),
            mergeCategory: .sndGroupEvent,
            unreadIds: BoxedValue(Set([800])),
            startIndexInReversedItems: 0,
            hash: "gh3"
        )
        XCTAssertTrue(merged.hasUnread())
    }

    func testGroupedItemNoUnread() {
        let chatItem = makeItem(900, status: .sndNew)
        let listItem = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 0)
        let merged = MergedItem.grouped(
            items: BoxedValue([listItem]),
            revealed: false,
            revealedIdsWithinGroup: BoxedValue([]),
            rangeInReversed: BoxedValue(0...0),
            mergeCategory: .chatFeature,
            unreadIds: BoxedValue(Set()),
            startIndexInReversedItems: 0,
            hash: "gh4"
        )
        XCTAssertFalse(merged.hasUnread())
    }

    func testGroupedItemLastIndexInReversed() {
        let items = (0..<3).map { ListItem(item: makeItem(Int64(1000 + $0)), prevItem: nil, nextItem: nil, unreadBefore: 0) }
        let merged = MergedItem.grouped(
            items: BoxedValue(items),
            revealed: false,
            revealedIdsWithinGroup: BoxedValue([]),
            rangeInReversed: BoxedValue(5...7),
            mergeCategory: .memberConnected,
            unreadIds: BoxedValue(Set()),
            startIndexInReversedItems: 5,
            hash: "gh5"
        )
        XCTAssertEqual(merged.lastIndexInReversed(), 7)
    }

    func testGroupedItemHashIncludesCount() {
        let items = (0..<4).map { ListItem(item: makeItem(Int64(1100 + $0)), prevItem: nil, nextItem: nil, unreadBefore: 0) }
        let merged = MergedItem.grouped(
            items: BoxedValue(items),
            revealed: false,
            revealedIdsWithinGroup: BoxedValue([]),
            rangeInReversed: BoxedValue(0...3),
            mergeCategory: .memberConnected,
            unreadIds: BoxedValue(Set()),
            startIndexInReversedItems: 0,
            hash: "base"
        )
        XCTAssertTrue(merged.hash.hasSuffix(" 4"), "Grouped hash should end with item count")
    }

    // MARK: - SplitRange

    func testSplitRangeCreation() {
        let split = SplitRange(itemId: 42, indexRangeInReversed: 0...5, indexRangeInParentItems: 0...5)
        XCTAssertEqual(split.itemId, 42)
        XCTAssertEqual(split.indexRangeInReversed, 0...5)
        XCTAssertEqual(split.indexRangeInParentItems, 0...5)
    }

    // MARK: - ListItem.genHash

    func testGenHashIsDeterministic() {
        let chatItem = makeItem(1200, text: "hello")
        let listItem = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 3)
        let hash1 = listItem.genHash(false, true)
        let hash2 = listItem.genHash(false, true)
        XCTAssertEqual(hash1, hash2)
    }

    func testGenHashDiffersWithDifferentRevealed() {
        let chatItem = makeItem(1300, text: "test")
        let listItem = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 0)
        let hash1 = listItem.genHash(true, false)
        let hash2 = listItem.genHash(false, true)
        XCTAssertNotEqual(hash1, hash2)
    }

    func testGenHashDiffersWithDifferentPrevNext() {
        let item1 = makeItem(1400, text: "a")
        let item2 = makeItem(1401, text: "b")
        let li1 = ListItem(item: item1, prevItem: nil, nextItem: item2, unreadBefore: 0)
        let li2 = ListItem(item: item1, prevItem: item2, nextItem: nil, unreadBefore: 0)
        XCTAssertNotEqual(li1.genHash(false, false), li2.genHash(false, false))
    }

    // MARK: - MergedItem equality

    func testMergedItemEqualityByHash() {
        let chatItem = makeItem(1500)
        let li = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 0)
        let a = MergedItem.single(item: li, startIndexInReversedItems: 0, hash: "same")
        let b = MergedItem.single(item: li, startIndexInReversedItems: 0, hash: "same")
        XCTAssertEqual(a, b)
    }

    func testMergedItemInequalityByHash() {
        let chatItem = makeItem(1600)
        let li = ListItem(item: chatItem, prevItem: nil, nextItem: nil, unreadBefore: 0)
        let a = MergedItem.single(item: li, startIndexInReversedItems: 0, hash: "x")
        let b = MergedItem.single(item: li, startIndexInReversedItems: 0, hash: "y")
        XCTAssertNotEqual(a, b)
    }
}
