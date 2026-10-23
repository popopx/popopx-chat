// Original Work Copyright (C) 2020-2022 simplex.chat
//
// --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
// This file was modified by POPOPX Team in 2026.
// Changes: Updated module reference comments from Simplex.Messaging.Crypto to Popopx.Messaging.Crypto.

// Cryptographic hash functions matching Popopx.Messaging.Crypto (sha256Hash, sha512Hash).

import sodium from "libsodium-wrappers-sumo"

// SHA-256 digest (32 bytes) -- Crypto.hs:1006
export function sha256(data: Uint8Array): Uint8Array {
  return sodium.crypto_hash_sha256(data)
}

// SHA-512 digest (64 bytes) -- Crypto.hs:1011
export function sha512(data: Uint8Array): Uint8Array {
  return sodium.crypto_hash_sha512(data)
}

// Streaming SHA-512 over multiple chunks -- avoids copying large data into WASM memory at once.
// Internally segments chunks larger than 4MB to limit peak WASM memory usage.
export function sha512Streaming(
  chunks: Iterable<Uint8Array>,
  onProgress?: (done: number, total: number) => void,
  totalBytes?: number
): Uint8Array {
  const SEG = 4 * 1024 * 1024
  const state = sodium.crypto_hash_sha512_init() as unknown as sodium.StateAddress
  let done = 0
  for (const chunk of chunks) {
    for (let off = 0; off < chunk.length; off += SEG) {
      const end = Math.min(off + SEG, chunk.length)
      sodium.crypto_hash_sha512_update(state, chunk.subarray(off, end))
      done += end - off
      onProgress?.(done, totalBytes ?? done)
    }
  }
  return sodium.crypto_hash_sha512_final(state)
}
