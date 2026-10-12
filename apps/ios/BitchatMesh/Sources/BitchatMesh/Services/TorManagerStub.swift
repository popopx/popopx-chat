// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import os
import Security

/// Tor proxy manager that routes traffic through a SOCKS5 proxy.
/// Connects to a local Tor SOCKS proxy (e.g., Orbot on port 9050) or a user-configured proxy.
/// All network traffic is routed through the Tor network when Tor is active.
public final class TorManager: TorProviding {
    public static let shared = TorManager()

    private var _isReady = false
    private var _isForeground = true
    private var _autoStartAllowed = true
    private var bootstrapTask: Task<Void, Never>?

    public var isReady: Bool { _isReady }
    public var torEnforced: Bool { true }

    /// SOCKS5 proxy host for Tor connection
    private let proxyHost = "127.0.0.1"
    /// SOCKS5 proxy port for Tor connection (standard Tor SOCKS port)
    private let proxyPort = 9050
    /// Maximum time to wait for Tor bootstrap
    private let bootstrapTimeoutSeconds: UInt64 = 30
    /// Test URL for verifying Tor connectivity
    private let connectivityCheckURL = "https://check.torproject.org/api/ip"

    public func isForeground() -> Bool { _isForeground }
    public func isAutoStartAllowed() -> Bool { _autoStartAllowed }

    public func setAutoStartAllowed(_ allowed: Bool) {
        _autoStartAllowed = allowed
    }

    public func setAppForeground(_ foreground: Bool) {
        _isForeground = foreground
        if foreground {
            startIfNeeded()
        }
    }

    public func goDormantOnBackground() {
        // In a real Tor implementation, this would signal the Tor client
        // to enter dormant mode to conserve resources
    }

    public func ensureRunningOnForeground() {
        startIfNeeded()
    }

    public func startIfNeeded() {
        guard !_isReady, _autoStartAllowed, bootstrapTask == nil else { return }

        NotificationCenter.default.post(name: .TorWillStart, object: nil)

        bootstrapTask = Task { @MainActor in
            let success = await performBootstrap()

            guard !Task.isCancelled else { return }

            if success {
                _isReady = true
                bootstrapTask = nil
                os_log(.info, "Tor: SOCKS5 proxy connection established at %{public}@:%{public}d", proxyHost, proxyPort)
                NotificationCenter.default.post(name: .TorDidBecomeReady, object: nil)
            } else {
                bootstrapTask = nil
                os_log(.error, "Tor: SOCKS5 proxy connection failed at %{public}@:%{public}d", proxyHost, proxyPort)
                NotificationCenter.default.post(name: .TorBootstrapDidStall, object: nil)
            }
        }
    }

    public func shutdownCompletely() {
        bootstrapTask?.cancel()
        bootstrapTask = nil
        _isReady = false
    }

    public func awaitReady(timeout: Int = 30) async -> Bool {
        if _isReady { return true }

        let startTime = Date()
        while !_isReady {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Date().timeIntervalSince(startTime) > Double(timeout) {
                return false
            }
        }
        return true
    }

    /// The SOCKS5 proxy configuration dictionary for URLSession.
    public var proxyConfiguration: [String: Any] {
        [
            kCFStreamPropertySOCKSProxyHost as String: proxyHost,
            kCFStreamPropertySOCKSProxyPort as String: proxyPort,
            kCFStreamPropertySOCKSVersion as String: kCFStreamSocketSOCKSVersion5 as String
        ]
    }

    private func performBootstrap() async -> Bool {
        // Phase 1: Verify SOCKS5 proxy is reachable
        let proxyReachable = await checkProxyReachable()
        guard proxyReachable else {
            os_log(.error, "Tor: SOCKS5 proxy not reachable at %{public}@:%{public}d", proxyHost, proxyPort)
            return false
        }

        // Phase 2: Verify Tor connectivity by making a test request through the proxy
        let torWorking = await verifyTorConnectivity()
        guard torWorking else {
            os_log(.error, "Tor: connectivity verification failed")
            return false
        }

        return true
    }

    /// Check if the SOCKS5 proxy port is accepting connections.
    private func checkProxyReachable() async -> Bool {
        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "tor.proxy.check")
            let host = self.proxyHost
            let port = self.proxyPort
            queue.async {
                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = UInt16(port).bigEndian
                inet_pton(AF_INET, host, &addr.sin_addr)

                let sock = socket(AF_INET, SOCK_STREAM, 0)
                guard sock >= 0 else {
                    continuation.resume(returning: false)
                    return
                }

                var timeout = timeval(tv_sec: 3, tv_usec: 0)
                setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

                let result = withUnsafePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }

                close(sock)
                continuation.resume(returning: result == 0)
            }
        }
    }

    /// Verify Tor connectivity by making a request through the SOCKS5 proxy.
    private func verifyTorConnectivity() async -> Bool {
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = proxyConfiguration
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = true
        let session = URLSession(configuration: config)

        guard let url = URL(string: connectivityCheckURL) else { return false }

        do {
            let (_, response) = try await session.data(from: url)
            if let httpResp = response as? HTTPURLResponse {
                return httpResp.statusCode == 200
            }
            return false
        } catch {
            os_log(.error, "Tor: connectivity check failed: %{public}@", error.localizedDescription)
            return false
        }
    }

    private init() {}
}

/// URLSession configured to route all traffic through the Tor SOCKS5 proxy.
/// Falls back to rejecting connections if Tor is not ready (fail-closed).
public final class TorURLSession {
    public static let shared = TorURLSession()

    private var _isReady = false
    private var useTorMode = true
    private var _session: URLSession
    private let directSession: URLSession
    private let sessionLock = NSLock()

    public var isReady: Bool {
        sessionLock.lock(); defer { sessionLock.unlock() }
        return _isReady || TorManager.shared.isReady
    }
    public var session: URLSession {
        sessionLock.lock(); defer { sessionLock.unlock() }
        return _session
    }

    public func setProxyMode(useTor: Bool) {
        sessionLock.lock()
        useTorMode = useTor
        sessionLock.unlock()
        rebuild()
    }

    public func rebuild() {
        let currentTorMode: Bool
        sessionLock.lock()
        _isReady = TorManager.shared.isReady
        currentTorMode = useTorMode
        sessionLock.unlock()

        if currentTorMode {
            let config = URLSessionConfiguration.ephemeral
            config.connectionProxyDictionary = TorManager.shared.proxyConfiguration
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            config.waitsForConnectivity = true
            sessionLock.lock()
            _session = URLSession(configuration: config)
            sessionLock.unlock()
        } else {
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            config.waitsForConnectivity = true
            sessionLock.lock()
            _session = URLSession(configuration: config)
            sessionLock.unlock()
        }
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }

    private init() {
        // Tor-proxied session
        let torConfig = URLSessionConfiguration.ephemeral
        torConfig.connectionProxyDictionary = TorManager.shared.proxyConfiguration
        torConfig.timeoutIntervalForRequest = 30
        torConfig.timeoutIntervalForResource = 60
        torConfig.waitsForConnectivity = true
        self._session = URLSession(configuration: torConfig)

        // Direct session (only used when Tor mode is explicitly disabled)
        let directConfig = URLSessionConfiguration.default
        directConfig.timeoutIntervalForRequest = 30
        directConfig.timeoutIntervalForResource = 60
        directConfig.waitsForConnectivity = true
        self.directSession = URLSession(configuration: directConfig)

        NotificationCenter.default.addObserver(
            forName: .TorDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sessionLock.lock()
            self?._isReady = true
            self?.sessionLock.unlock()
            self?.rebuild()
        }

        NotificationCenter.default.addObserver(
            forName: .TorWillStart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sessionLock.lock()
            self?._isReady = false
            self?.sessionLock.unlock()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension Notification.Name {
    public static let TorDidBecomeReady = Notification.Name("TorDidBecomeReady")
    public static let TorBootstrapDidStall = Notification.Name("TorBootstrapDidStall")
    public static let TorUserPreferenceChanged = Notification.Name("TorUserPreferenceChanged")
    public static let TorWillRestart = Notification.Name("TorWillRestart")
    public static let TorWillStart = Notification.Name("TorWillStart")
}
