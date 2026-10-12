//
//  Emoji.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 04/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import SwiftUI

private func isSimpleEmoji(_ c: Character) -> Bool {
    guard let firstScalar = c.unicodeScalars.first else { return false }
    return firstScalar.properties.isEmoji && firstScalar.value > 0x238C
}

private func isCombinedIntoEmoji(_ c: Character) -> Bool {
    c.unicodeScalars.count > 1 && c.unicodeScalars.first?.properties.isEmoji ?? false
}

func isEmoji(_ c: Character) -> Bool {
    isSimpleEmoji(c) || isCombinedIntoEmoji(c)
}

private let pxLargeEmojiSize: CGFloat = 48
private let pxMediumEmojiSize: CGFloat = 36
private let pxMaxShortEmojiCount: Int = 5

let largeEmojiFont = Font.custom("Emoji", size: pxLargeEmojiSize, relativeTo: .largeTitle)
let largeEmojiUIFont: UIFont = UIFont(name: "Emoji", size: pxLargeEmojiSize) ?? UIFont.systemFont(ofSize: pxLargeEmojiSize)
let mediumEmojiFont = Font.custom("Emoji", size: pxMediumEmojiSize, relativeTo: .largeTitle)
let mediumEmojiUIFont: UIFont = UIFont(name: "Emoji", size: pxMediumEmojiSize) ?? UIFont.systemFont(ofSize: pxMediumEmojiSize)

func isShortEmoji(_ str: String) -> Bool {
    let s = str.trimmingCharacters(in: .whitespaces)
    return s.count > 0 && s.count <= pxMaxShortEmojiCount && s.allSatisfy(isEmoji)
}

// MARK: - POPOPX
enum PXEmojiTags {
    static let pxComponentTag: String = "PX_EMOJI"
    static let pxLargeSize: CGFloat = pxLargeEmojiSize
    static let pxMediumSize: CGFloat = pxMediumEmojiSize
}
