//
//  SharedFileSubscriber.swift
//  POPOPXSwitch
//
//  Created by Evgeny on 09/12/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation

public typealias AppSubscriber = SharedFileSubscriber<ProcessMessage<AppProcessMessage>>

public typealias NSESubscriber = SharedFileSubscriber<ProcessMessage<NSEProcessMessage>>

public typealias SESubscriber = SharedFileSubscriber<ProcessMessage<SEProcessMessage>>

public class SharedFileSubscriber<Message: Codable>: NSObject, NSFilePresenter {
    var fileURL: URL
    public var presentedItemURL: URL?
    public var presentedItemOperationQueue: OperationQueue
    var subscriber: ((Message) -> Void)?

    init(fileURL: URL, onMessage: @escaping (Message) -> Void) {
        self.fileURL = fileURL
        presentedItemURL = fileURL
        subscriber = onMessage
        let queue = OperationQueue()
        queue.name = "SharedFileSubscriber-\(fileURL.lastPathComponent)"
        queue.qualityOfService = .background
        presentedItemOperationQueue = queue
        super.init()
        // Note: callers must invoke register() to start observing.
        // NSFileCoordinator retains presenters, so registering in init would create a retain cycle.
    }

    /// Registers this subscriber as a file presenter with NSFileCoordinator.
    /// Must be called after init to start observing file changes.
    public func register() {
        NSFileCoordinator.addFilePresenter(self)
    }

    /// Unregisters this subscriber from NSFileCoordinator.
    /// Must be called when the subscriber is no longer needed to break the retain cycle.
    public func deregister() {
        NSFileCoordinator.removeFilePresenter(self)
        subscriber = nil
    }

    public func presentedItemDidChange() {
        do {
            let data = try Data(contentsOf: fileURL)
            let msg = try jsonDecoder.decode(Message.self, from: data)
            DispatchQueue.main.async { [weak self] in
                self?.subscriber?(msg)
            }
        } catch let error {
            logger.error("presentedItemDidChange error: \(error)")
        }
    }

    static func notify(url: URL, message: Message) {
        let fc = NSFileCoordinator(filePresenter: nil)
        fc.coordinate(writingItemAt: url, options: [], error: nil) { newURL in
            do {
                let data = try jsonEncoder.encode(message)
                try data.write(to: newURL, options: [.atomic, .completeFileProtection])
            } catch {
                logger.error("notifyViaSharedFile error: \(error)")
            }
        }
    }

    // Note: deinit will not run while registered with NSFileCoordinator (which retains presenters).
    // Callers must invoke deregister() to break the retain cycle.
}

let appMessagesSharedFile = getGroupContainerDirectory().appendingPathComponent("com.popopxchat.popopx.messages", isDirectory: false)

let nseMessagesSharedFile = getGroupContainerDirectory().appendingPathComponent("com.popopxchat.popopx.POPOPX-NSE.messages", isDirectory: false)

let seMessagesSharedFile = getGroupContainerDirectory().appendingPathComponent("com.popopxchat.popopx.POPOPX-SE.messages", isDirectory: false)

public struct ProcessMessage<Message: Codable>: Codable {
    var createdAt: Date = Date.now
    var message: Message
}

public enum AppProcessMessage: Codable {
    case state(state: AppState)
}

public enum NSEProcessMessage: Codable {
    case state(state: NSEState)
}

public enum SEProcessMessage: Codable {
    case state(state: SEState)
}

public func sendAppProcessMessage(_ message: AppProcessMessage) {
    SharedFileSubscriber.notify(url: appMessagesSharedFile, message: ProcessMessage(message: message))
}

public func sendNSEProcessMessage(_ message: NSEProcessMessage) {
    SharedFileSubscriber.notify(url: nseMessagesSharedFile, message: ProcessMessage(message: message))
}

public func sendSEProcessMessage(_ message: SEProcessMessage) {
    SharedFileSubscriber.notify(url: seMessagesSharedFile, message: ProcessMessage(message: message))
}

public func appMessageSubscriber(onMessage: @escaping (AppProcessMessage) -> Void) -> AppSubscriber {
    let sub = SharedFileSubscriber(fileURL: appMessagesSharedFile) { (msg: ProcessMessage<AppProcessMessage>) in
        onMessage(msg.message)
    }
    sub.register()
    return sub
}

public func nseMessageSubscriber(onMessage: @escaping (NSEProcessMessage) -> Void) -> NSESubscriber {
    let sub = SharedFileSubscriber(fileURL: nseMessagesSharedFile) { (msg: ProcessMessage<NSEProcessMessage>) in
        onMessage(msg.message)
    }
    sub.register()
    return sub
}

public func seMessageSubscriber(onMessage: @escaping (SEProcessMessage) -> Void) -> SESubscriber {
    let sub = SharedFileSubscriber(fileURL: seMessagesSharedFile) { (msg: ProcessMessage<SEProcessMessage>) in
        onMessage(msg.message)
    }
    sub.register()
    return sub
}

public func sendAppState(_ state: AppState) {
    sendAppProcessMessage(.state(state: state))
}

public func sendNSEState(_ state: NSEState) {
    sendNSEProcessMessage(.state(state: state))
}

public func sendSEState(_ state: SEState) {
    sendSEProcessMessage(.state(state: state))
}
