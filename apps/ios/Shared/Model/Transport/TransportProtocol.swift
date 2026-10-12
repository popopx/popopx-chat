// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation

protocol MessageTransport: AnyObject {
    var transportID: String { get }
    var isAvailable: Bool { get }
    var onMessageReceived: ((TransportMessage) -> Void)? { get set }
    var onAvailabilityChanged: ((Bool) -> Void)? { get set }

    func send(_ message: TransportMessage, completion: @escaping (Result<Void, TransportError>) -> Void)
    func start() throws
    func stop()
}

struct TransportMessage: Equatable {
    let id: String
    let senderID: String?
    let recipientID: String?
    let payload: Data
    let priority: Priority
    let transportHint: String?

    init(id: String, senderID: String? = nil, recipientID: String? = nil, payload: Data, priority: Priority = .normal, transportHint: String? = nil) {
        self.id = id
        self.senderID = senderID
        self.recipientID = recipientID
        self.payload = payload
        self.priority = priority
        self.transportHint = transportHint
    }

    enum Priority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

enum TransportError: Error, Equatable {
    case notAvailable
    case sendFailed(String)
    case encodingFailed
    case peerNotFound
    case transportStopped
}

struct MeshInboxMessage: Identifiable {
    let id: String
    let senderID: String
    let text: String
    let receivedAt: Date
}
