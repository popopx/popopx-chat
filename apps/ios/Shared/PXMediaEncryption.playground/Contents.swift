// POPOPX Media Encryption Playground
// Demonstrates AES-GCM encrypt/decrypt cycle for media chunks
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import UIKit
import POPOPXSwitch

hs_init(0, nil)

enum PXMediaCryptoVerifier {
    static let headerSize = 20
    static let ivTagOverhead = 28
    static let keyFrameThreshold = 10
    static let deltaFrameThreshold = 3

    static func run() {
        let buffer = allocateBuffer(size: headerSize)
        markKeyFrame(buffer, size: headerSize)

        let plaintext = NSData(bytesNoCopy: buffer, length: headerSize)
        let cryptoKey = generateAES256Key()

        guard let keyChars = cryptoKey.cString(using: .utf8),
              let workBuffer = malloc(plaintext.count + ivTagOverhead) else {
            fatalError("PXMediaCryptoVerifier: allocation failed")
        }

        memcpy(workBuffer, plaintext.bytes, plaintext.count)
        let originalData = Data(bytes: workBuffer, count: plaintext.count)
        let isKeyFrame = plaintext[0] & 1 == 0
        let clearHeaderSize = isKeyFrame ? keyFrameThreshold : deltaFrameThreshold

        dumpBuffer("Pre-encrypt", workBuffer, count: 48)

        if let errPtr = chat_encrypt_media(&keyChars, workBuffer.advanced(by: clearHeaderSize), Int32(plaintext.count + ivTagOverhead - clearHeaderSize)) {
            reportResult("encrypt", errPtr)
        }

        dumpBuffer("Post-encrypt", workBuffer, count: 48)
        let encryptedBlob = Data(bytes: workBuffer, count: plaintext.count + ivTagOverhead)
        print("Data preserved after encrypt: \(originalData == encryptedBlob)")

        if let errPtr = chat_decrypt_media(&keyChars, workBuffer.advanced(by: clearHeaderSize), Int32(plaintext.count + ivTagOverhead - clearHeaderSize)) {
            reportResult("decrypt", errPtr)
        }

        dumpBuffer("Post-decrypt", workBuffer, count: 48)
        let recoveredData = Data(bytes: workBuffer, count: plaintext.count)
        print("Round-trip success: \(originalData == recoveredData)")

        free(buffer)
        free(workBuffer)
    }

    private static func allocateBuffer(size: Int) -> UnsafeMutableRawPointer {
        let ptr = malloc(size)
        memset(ptr, 0, size)
        return ptr!
    }

    private static func markKeyFrame(_ buffer: UnsafeMutableRawPointer, size: Int) {
        let typed = buffer.assumingMemoryBound(to: UInt8.self)
        typed[0] = 0
        for offset in 1..<size {
            typed[offset] = UInt8(offset)
        }
    }

    private static func generateAES256Key() -> String {
        var rawKey = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, rawKey.count, &rawKey)
        return Data(rawKey).base64EncodedString()
    }

    private static func dumpBuffer(_ label: String, _ ptr: UnsafeMutableRawPointer, count: Int) {
        let typed = ptr.assumingMemoryBound(to: UInt8.self)
        for idx in 0..<count {
            debugPrint("\(label)[\(idx)] = \(typed[idx])")
        }
    }

    private static func reportResult(_ operation: String, _ errPtr: UnsafeMutablePointer<CChar>) {
        let message = fromCString(errPtr)
        if message.isEmpty {
            print("\(operation) ok")
        } else {
            print("\(operation) error: \(message)")
        }
    }
}

PXMediaCryptoVerifier.run()
