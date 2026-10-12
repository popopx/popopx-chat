// POPOPX customized debug playground
// Usage: paste JSON into `pxRawInput` and evaluate in Xcode playground
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import POPOPXSwitch

// MARK: - POPOPX Debug Configuration
private enum PXDebugConfig {
    static let pxDefaultPayload = "{}"
    static let pxTimestampSample = "\"2022-04-24T11:59:23.703162Z\""
}

// POPOPX: the raw JSON to decode – swap with pxTimestampSample for timestamp testing
let pxRawInput =
"""
\(PXDebugConfig.pxDefaultPayload)
"""

// POPOPX: decode and print the result
private func pxDecodeAndPrint() {
    let pxDecoder = getJSONDecoder()
    let pxData = pxRawInput.data(using: .utf8) ?? Data()
    do {
        let pxResult = try pxDecoder.decode(APIResponse.self, from: pxData)
        print("PX decoded: \(pxResult)")
    } catch let pxError {
        print("PX decode failed: \(pxError.localizedDescription)")
    }
}

pxDecodeAndPrint()
