// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import os
import UIKit

/// Manages saving and loading media files received/sent via mesh transport.
@MainActor
final class MeshMediaStore {
    static let shared = MeshMediaStore()

    private let fileManager = FileManager.default
    private lazy var baseDir: URL = {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            os_log(.error, "MeshMediaStore: cannot find document directory")
            return URL.documentsDirectory.appendingPathComponent("mesh_media", isDirectory: true)
        }
        let dir = docs.appendingPathComponent("mesh_media", isDirectory: true)
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: dir.path)
        } catch {
            os_log(.error, "MeshMediaStore: failed to create base directory: %{public}@", error.localizedDescription)
        }
        return dir
    }()

    private let maxStorageBytes: Int = 100 * 1024 * 1024
    private let maxFileAge: TimeInterval = 30 * 24 * 60 * 60

    /// In-memory image cache; automatically purged on memory pressure.
    private let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 20 * 1024 * 1024 // 20 MB
        return cache
    }()

    private var memoryWarningObserver: NSObjectProtocol?

    private init() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.imageCache.removeAllObjects()
                os_log(.info, "MeshMediaStore: cleared image cache on memory warning")
                self.cleanup()
            }
        }
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Image cache

    func cachedImage(for key: String) -> UIImage? {
        imageCache.object(forKey: key as NSString)
    }

    func setCachedImage(_ image: UIImage, for key: String, cost: Int) {
        imageCache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func evictImageCache() {
        imageCache.removeAllObjects()
    }

    func saveVoice(_ data: Data, fileName: String) -> String? {
        let path = save(data, subdirectory: "voice", fileName: fileName)
        Task { @MainActor in cleanup() }
        return path
    }

    func saveImage(_ data: Data, fileName: String) -> String? {
        let path = save(data, subdirectory: "images", fileName: fileName)
        Task { @MainActor in cleanup() }
        return path
    }

    func saveFile(_ data: Data, fileName: String) -> String? {
        let path = save(data, subdirectory: "files", fileName: fileName)
        Task { @MainActor in cleanup() }
        return path
    }

    private func save(_ data: Data, subdirectory: String, fileName: String) -> String? {
        let dir = baseDir.appendingPathComponent(subdirectory, isDirectory: true)
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: dir.path)
        } catch {
            os_log(.error, "MeshMediaStore: failed to create directory: %{public}@", error.localizedDescription)
            return nil
        }
        let url = dir.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            var mutableURL = url
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? mutableURL.setResourceValues(resourceValues)
            return url.path
        } catch {
            os_log(.error, "MeshMediaStore.save: failed to write file: %{public}@", error.localizedDescription)
            return nil
        }
    }

    func deleteAll() {
        try? fileManager.removeItem(at: baseDir)
    }

    func cleanup() {
        guard let enumerator = fileManager.enumerator(at: baseDir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { return }
        let now = Date()
        var files: [(url: URL, date: Date, size: Int)] = []

        for case let fileURL as URL in enumerator {
            guard let attrs = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let date = attrs.contentModificationDate,
                  let size = attrs.fileSize else { continue }
            if now.timeIntervalSince(date) > maxFileAge {
                try? fileManager.removeItem(at: fileURL)
            } else {
                files.append((fileURL, date, size))
            }
        }

        let totalSize = files.reduce(0) { $0 + $1.size }
        if totalSize > maxStorageBytes {
            let sorted = files.sorted { $0.date < $1.date }
            var freed = 0
            for file in sorted {
                if totalSize - freed <= maxStorageBytes { break }
                try? fileManager.removeItem(at: file.url)
                freed += file.size
            }
        }
    }
}
