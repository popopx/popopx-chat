//
//  WebRTCProtocol.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 03/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import POPOPXSwitch

actor WebRTCCommandProcessor {
    private var client: WebRTCClient? = nil
    private var commands: [WCallCommand] = []
    private var running: Bool = false

    func setClient(_ client: WebRTCClient?) async {
        logger.debug("WebRTC: setClient, commands count \(self.commands.count)")
        self.client = client
        if client != nil {
            await processAllCommands()
        } else {
            commands.removeAll()
        }
    }

    func processCommand(_ c: WCallCommand) async {
        commands.append(c)
        if !running && client != nil {
            await processAllCommands()
        }
    }

    func processAllCommands() async {
        logger.debug("WebRTC: process all commands, commands count \(self.commands.count), client == nil \(self.client == nil)")
        if let client = client {
            running = true
            while let c = commands.first, shouldRunCommand(client, c) {
                commands.remove(at: 0)
                await client.sendCallCommand(command: c)
                logger.debug("WebRTC: processed cmd \(c.cmdType)")
            }
            running = false
        }
    }

    func shouldRunCommand(_ client: WebRTCClient, _ c: WCallCommand) -> Bool {
        switch c {
        case .capabilities, .start, .offer, .end: true
        default: client.activeCall != nil
        }
    }
}

// MARK: - POPOPX
fileprivate let _pxBrandWebRTCProtocol = "PX_WEB_RTC_PROTOCOL"
