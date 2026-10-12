//
//  NetworkObserver.swift
//  POPOPX (iOS)
//
//  Created by Avently on 05.04.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import Network
import POPOPXSwitch

class NetworkObserver {
    static let shared = NetworkObserver()
    private let queue: DispatchQueue = DispatchQueue(label: "com.popopxchat.popopx.NetworkObserver")
    private var prevInfo: UserNetworkInfo? = nil
    private var monitor: NWPathMonitor?
    private let monitorLock: DispatchQueue = DispatchQueue(label: "com.popopxchat.popopx.monitorLock")

    func restartMonitor() {
        monitorLock.sync {
            monitor?.cancel()
            let mon = NWPathMonitor()
            mon.pathUpdateHandler = { [weak self] path in
                // Always process on our serial queue to protect prevInfo
                self?.queue.async {
                    self?.networkPathChanged(path: path)
                }
            }
            mon.start(queue: queue)
            monitor = mon
        }
    }

    private func networkPathChanged(path: NWPath) {
        let info = UserNetworkInfo(
            networkType: networkTypeFromPath(path),
            online: path.status == .satisfied
        )
        if (prevInfo != info) {
            prevInfo = info
            setNetworkInfo(info)
        }
    }

    private func networkTypeFromPath(_ path: NWPath) -> UserNetworkType {
        if path.usesInterfaceType(.wiredEthernet) {
            .ethernet
        } else if path.usesInterfaceType(.wifi) {
            .wifi
        } else if path.usesInterfaceType(.cellular) {
            .cellular
        } else if path.usesInterfaceType(.other) {
            .other
        } else {
            .none
        }
    }

    private func setNetworkInfo(_ info: UserNetworkInfo) {
        logger.debug("setNetworkInfo Network changed: \(String(describing: info))")
        DispatchQueue.main.async {
            ChatModel.shared.networkInfo = info
        }
        Task { @MainActor in
            TransportManager.shared.updateInternetAvailability(info.online)
        }
        Task { @MainActor in handleTransportSwitch(online: info.online) }
        if !hasChatCtrl() { return }
        ffiQueue.async { [info] in
            do {
                try apiSetNetworkInfo(info)
            } catch let err {
                logger.error("setNetworkInfo error: \(responseError(err))")
            }
        }
    }

    @MainActor
    private func handleTransportSwitch(online: Bool) {
        guard ChatModel.shared.meshAutoSwitch else { return }
        let router = ChatModel.shared.transportRouter
        Task { @MainActor in
            if online {
                await router.setPreferredTransport("internet")
                await router.flushQueue()
                let count = await router.queuedMessageCount
                ChatModel.shared.currentTransportID = "internet"
                ChatModel.shared.activeTransportName = "Online"
                ChatModel.shared.queuedMessageCount = count
            } else {
                let available = await router.availableTransports
                if available.contains("multipeer") {
                    await router.setPreferredTransport("multipeer")
                    await router.flushQueue()
                    let count = await router.queuedMessageCount
                    ChatModel.shared.currentTransportID = "multipeer"
                    ChatModel.shared.activeTransportName = "Multipeer"
                    ChatModel.shared.queuedMessageCount = count
                } else if available.contains("bluetooth") {
                    await router.setPreferredTransport("bluetooth")
                    await router.flushQueue()
                    let count = await router.queuedMessageCount
                    ChatModel.shared.currentTransportID = "bluetooth"
                    ChatModel.shared.activeTransportName = "Bluetooth Mesh"
                    ChatModel.shared.queuedMessageCount = count
                }
            }
        }
    }
}
