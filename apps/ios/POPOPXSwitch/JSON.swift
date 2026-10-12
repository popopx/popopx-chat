//
//  JSON.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 29/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation

public func getJSONDecoder() -> JSONDecoder {
    let jd = JSONDecoder()
    let fracSeconds = getDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ")
    let noFracSeconds = getDateFormatter("yyyy-MM-dd'T'HH:mm:ssZZZZZ")
    jd.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = fracSeconds.date(from: string) ?? noFracSeconds.date(from: string) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
    }
    return jd
}

public func getJSONEncoder() -> JSONEncoder {
    let je = JSONEncoder()
    je.dateEncodingStrategy = .iso8601
    return je
}

private func getDateFormatter(_ format: String) -> DateFormatter {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.dateFormat = format
    df.timeZone = TimeZone(secondsFromGMT: 0)
    return df
}
