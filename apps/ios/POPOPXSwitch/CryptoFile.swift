//
//  CryptoFile.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 05/09/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
// Spec: spec/services/files.md
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation

enum WriteFileResult: Decodable {
    case result(cryptoArgs: CryptoFileArgs)
    case error(writeError: String)
}

// Spec: spec/services/files.md#writeCryptoFile
public func writeCryptoFile(path: String, data: Data) throws -> CryptoFileArgs {
    guard data.count > 0 else { throw RuntimeError("writeCryptoFile: empty data") }
    guard let ptr = malloc(data.count) else { throw RuntimeError("writeCryptoFile: malloc failed") }
    memcpy(ptr, (data as NSData).bytes, data.count)
    defer { memset_s(ptr, data.count, 0, data.count); free(ptr) }
    guard var cPath = path.cString(using: .utf8) else {
        throw RuntimeError("writeCryptoFile: invalid path encoding")
    }
    guard let ctrl = getChatCtrl() else {
        throw RuntimeError("chat controller not initialized")
    }
    guard let cSize = Int32(exactly: data.count) else {
        throw RuntimeError("writeCryptoFile: data too large (\(data.count) bytes exceeds Int32 limit)")
    }
    guard let cjson = chat_write_file(ctrl, &cPath, ptr, cSize) else {
        throw RuntimeError("chat_write_file returned null")
    }
    guard let d = dataFromCString(cjson) else {
        throw RuntimeError("dataFromCString returned null")
    }
    switch try jsonDecoder.decode(WriteFileResult.self, from: d) {
    case let .result(cfArgs):
        return cfArgs
    case let .error(err):
        throw RuntimeError(err)
    }
}

// Spec: spec/services/files.md#readCryptoFile
public func readCryptoFile(path: String, cryptoArgs: CryptoFileArgs) throws -> Data {
    guard var cPath = path.cString(using: .utf8) else { throw RuntimeError("readCryptoFile: invalid path encoding") }
    guard var cKey = cryptoArgs.fileKey.cString(using: .utf8) else { throw RuntimeError("readCryptoFile: invalid key encoding") }
    guard var cNonce = cryptoArgs.fileNonce.cString(using: .utf8) else { throw RuntimeError("readCryptoFile: invalid nonce encoding") }
    guard let ptr = chat_read_file(&cPath, &cKey, &cNonce) else {
        throw RuntimeError("chat_read_file returned null")
    }
    let status = UInt8(ptr.pointee)
    switch status {
    case 0: // ok
        // Read 4-byte length as little-endian UInt32 using byte-by-byte construction
        // to avoid unaligned memory access on ARM64
        let lenBytes = Data(bytes: ptr.advanced(by: 1), count: 4)
        guard lenBytes.count >= 4 else {
            memset(ptr, 0, 1)
            free(ptr)
            throw RuntimeError("chat_read_file: insufficient length header (\(lenBytes.count) bytes)")
        }
        let len = UInt32(lenBytes[0]) |
                  (UInt32(lenBytes[1]) << 8) |
                  (UInt32(lenBytes[2]) << 16) |
                  (UInt32(lenBytes[3]) << 24)
        let dataLen = Int(len)
        guard dataLen >= 0, dataLen <= 100_000_000 else {
            memset(ptr, 0, 5)
            free(ptr)
            throw RuntimeError("chat_read_file: invalid data length \(dataLen)")
        }
        let d = Data(bytes: ptr.advanced(by: 5), count: dataLen)
        memset(ptr, 0, 5 + dataLen)
        free(ptr)
        return d
    case 1: // error
        let err = String(cString: ptr.advanced(by: 1))
        free(ptr)
        throw RuntimeError(err)
    default:
        free(ptr)
        throw RuntimeError("unexpected chat_read_file status: \(status)")
    }
}

// Spec: spec/services/files.md#encryptCryptoFile
public func encryptCryptoFile(fromPath: String, toPath: String) throws -> CryptoFileArgs {
    guard var cFromPath = fromPath.cString(using: .utf8) else { throw RuntimeError("encryptCryptoFile: invalid fromPath encoding") }
    guard var cToPath = toPath.cString(using: .utf8) else { throw RuntimeError("encryptCryptoFile: invalid toPath encoding") }
    guard let ctrl = getChatCtrl() else {
        throw RuntimeError("chat controller not initialized")
    }
    guard let cjson = chat_encrypt_file(ctrl, &cFromPath, &cToPath) else {
        throw RuntimeError("chat_encrypt_file returned null")
    }
    guard let d = dataFromCString(cjson) else {
        throw RuntimeError("dataFromCString returned null")
    }
    switch try jsonDecoder.decode(WriteFileResult.self, from: d) {
    case let .result(cfArgs): return cfArgs
    case let .error(err): throw RuntimeError(err)
    }
}

public enum CryptoFileError: Error, CustomStringConvertible {
    case invalidEncoding(String)
    case ffiNull
    case decryptionFailed(String)
    case unknownStatus(UInt8)

    public var isRecoverable: Bool {
        switch self {
        case .decryptionFailed: return false
        case .invalidEncoding, .ffiNull, .unknownStatus: return true
        }
    }

    public var description: String {
        switch self {
        case .invalidEncoding(let field): return "Invalid encoding: \(field)"
        case .ffiNull: return "FFI returned null"
        case .decryptionFailed(let msg): return "Decryption failed: \(msg)"
        case .unknownStatus(let s): return "Unknown status: \(s)"
        }
    }
}

// Spec: spec/services/files.md#decryptCryptoFile
public func decryptCryptoFile(fromPath: String, cryptoArgs: CryptoFileArgs, toPath: String) throws {
    guard var cFromPath = fromPath.cString(using: .utf8) else { throw CryptoFileError.invalidEncoding("fromPath") }
    guard var cKey = cryptoArgs.fileKey.cString(using: .utf8) else { throw CryptoFileError.invalidEncoding("fileKey") }
    guard var cNonce = cryptoArgs.fileNonce.cString(using: .utf8) else { throw CryptoFileError.invalidEncoding("fileNonce") }
    guard var cToPath = toPath.cString(using: .utf8) else { throw CryptoFileError.invalidEncoding("toPath") }
    guard let cErr = chat_decrypt_file(&cFromPath, &cKey, &cNonce, &cToPath) else {
        throw CryptoFileError.ffiNull
    }
    let err = fromCString(cErr)
    if err != "" { throw CryptoFileError.decryptionFailed(err) }
}
