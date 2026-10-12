//
//  NameBadge.swift
//  POPOPX
//
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxBadgeFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_FEATURE_ENABLED")

// POPOPX: badge sizing ratios – calibrated for POPOPX typography scale
// The badge is sized to a fraction of the font size (em), NOT the font's cap-height metric: the metric
// underestimates the rendered capital letters, so a cap-height-tall badge looks too small.
private enum PXBadgeMetrics {
    static let pxCapHeightFraction: CGFloat = 0.89
    static let pxBaselineUndershoot: CGFloat = 0.08
    static let pxExpiredAlpha: CGFloat = 0.30
    static let pxWarningTint: Color = QuantumColors.warning
}

// A contact/member name with the supporter badge right after it. The name keeps its own styling
// (font, weight, color, even a verification shield concatenated into the Text); the badge is sized to
// the given text style and sits on the name's baseline. Use this everywhere a name may carry a badge.
// Pass onTap to make the badge open the info alert. The badge hides itself for a nil/long-expired badge.
struct NameWithBadge: View {
    let name: Text
    var badge: LocalBadge?
    var textStyle: UIFont.TextStyle = .body
    var onTap: (() -> Void)? = nil

    init(_ name: Text, _ badge: LocalBadge?, _ textStyle: UIFont.TextStyle = .body, onTap: (() -> Void)? = nil) {
        self.name = name
        self.badge = badge
        self.textStyle = textStyle
        self.onTap = onTap
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            NameBadge(badge, textStyle, onTap: onTap)
            name
        }
        .popopxBranded()
    }
}

// The badge glyph alone, sized to the given text style and sitting on the text baseline in an
// HStack(alignment: .firstTextBaseline). Renders nothing for a nil badge or a long-expired one
// (ExpiredOld); a failed or unknown-key badge shows a warning glyph. Prefer NameWithBadge; use this
// directly only where the name is not a single Text. Pass onTap to open the badge info alert.
struct NameBadge: View {
    var badge: LocalBadge?
    var textStyle: UIFont.TextStyle = .body
    var onTap: (() -> Void)? = nil

    init(_ badge: LocalBadge?, _ textStyle: UIFont.TextStyle = .body, onTap: (() -> Void)? = nil) {
        self.badge = badge
        self.textStyle = textStyle
        self.onTap = onTap
    }

    var body: some View {
        if let badge, badge.status != .expiredOld {
            // POPOPX: the leading padding is the gap to the name; it lives here so an absent badge adds no gap.
            // the alignment guide pushes the badge bottom slightly below the baseline (round-letter undershoot)
            let pxGlyphView = pxBuildGlyph(badge)
                .padding(.leading, pxComputeBadgeGap)
                .frame(height: pxComputeBadgeHeight)
                .alignmentGuide(.firstTextBaseline) { $0.height * (1 - PXBadgeMetrics.pxBaselineUndershoot) }
            if let onTap {
                pxGlyphView.onTapGesture(perform: onTap)
            } else {
                pxGlyphView
            }
        }
    }

    // POPOPX: extracted computed properties for badge dimensions
    private var pxComputeBadgeHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: textStyle).pointSize * PXBadgeMetrics.pxCapHeightFraction
    }

    // the gap to the name, matching the verification shield's gap (textSpace - one space in the name's font)
    private var pxComputeBadgeGap: CGFloat {
        let pxFont = UIFont.preferredFont(forTextStyle: textStyle)
        return (" " as NSString).size(withAttributes: [.font: pxFont]).width
    }

    // POPOPX: build the glyph view based on badge status
    @ViewBuilder private func pxBuildGlyph(_ badge: LocalBadge) -> some View {
        switch badge.status {
        case .failed, .unknownKey:
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable().scaledToFit()
                .foregroundColor(PXBadgeMetrics.pxWarningTint)
                .accessibilityLabel(Text(NSLocalizedString("Warning", comment: "accessibility label for warning badge")))
        default:
            Image(pxResolveImageName(badge.badge.badgeType))
                .resizable().scaledToFit()
                .opacity(badge.status == .expired ? PXBadgeMetrics.pxExpiredAlpha : 1)
        }
    }

    // POPOPX: resolve badge image name from type
    private func pxResolveImageName(_ t: BadgeType) -> String {
        switch t {
        case .legend: "badge-legend"
        case .investor: "badge-investor"
        default: "badge-supporter"
        }
    }
}

func badgeImageName(_ t: BadgeType) -> String {
    switch t {
    case .legend: "badge-legend"
    case .investor: "badge-investor"
    default: "badge-supporter" // supporter + unknown
    }
}

// The badge as an inline attachment for a UIKit label, for the custom alert where the name is a UILabel
// and the SwiftUI NameBadge can't be used. Sized to the font's cap height with its bottom on the baseline,
// preceded by a space for the gap to the name. Returns nil for a nil/long-expired badge. Mirrors NameBadge's glyph.
func nameBadgeAttachment(_ badge: LocalBadge?, font: UIFont) -> NSAttributedString? {
    guard let badge, badge.status != .expiredOld else { return nil }
    var pxImage: UIImage?
    switch badge.status {
    case .failed, .unknownKey:
        pxImage = UIImage(systemName: "exclamationmark.triangle.fill")?
            .withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
    default:
        pxImage = UIImage(named: badgeImageName(badge.badge.badgeType))
        if badge.status == .expired, let pxSource = pxImage {
            pxImage = pxRenderDimmedBadgeImage(pxSource)
        }
    }
    guard let pxFinalImage = pxImage else { return nil }
    let pxAttachment = NSTextAttachment()
    pxAttachment.image = pxFinalImage
    let pxH = font.pointSize * PXBadgeMetrics.pxCapHeightFraction
    // POPOPX: negative y drops the image below the baseline by pxBaselineUndershoot of its height
    let pxWidth = pxH * pxFinalImage.size.width / pxFinalImage.size.height
    pxAttachment.bounds = CGRect(x: 0, y: -pxH * PXBadgeMetrics.pxBaselineUndershoot, width: pxWidth, height: pxH)
    let pxAttrStr = NSMutableAttributedString(string: " ") // the gap to the name
    pxAttrStr.append(NSAttributedString(attachment: pxAttachment))
    return pxAttrStr
}

// MARK: - POPOPX
private func pxRenderDimmedBadgeImage(_ img: UIImage) -> UIImage? {
    return UIGraphicsImageRenderer(size: img.size).image { _ in
        img.draw(at: .zero, blendMode: .normal, alpha: PXBadgeMetrics.pxExpiredAlpha)
    }
}

// POPOPX: display the badge info alert with POPOPX-specific wording
@MainActor
func showBadgeInfoAlert(_ name: String, _ badge: LocalBadge) {
    logger.debug("PX: [showBadgeInfoAlert] name=\(name), status=\(String(describing: badge.status))")
    switch badge.status {
    case .failed:
        showAlert(
            NSLocalizedString("Unverified badge", comment: "badge alert title"),
            message: NSLocalizedString("This badge could not be verified and may not be genuine.", comment: "badge alert")
        )
    case .unknownKey:
        showAlert(
            NSLocalizedString("Badge cannot be verified", comment: "badge alert title"),
            message: NSLocalizedString("The badge is signed with a key that this version of the app does not recognize. Update the app to verify this badge.", comment: "badge alert")
        )
    default:
        // POPOPX: a verified badge's type is signed and can't be faked
        let pxTitle = badgeTypeName(badge.badge.badgeType)
        if case .investor = badge.badge.badgeType {
            let pxMessage = String.localizedStringWithFormat(NSLocalizedString("%@ invested in POPOPX Chat crowdfunding.", comment: "badge alert"), name)
            showAlert(pxTitle, message: pxMessage) {
                [ UIAlertAction(title: NSLocalizedString("Learn more", comment: "badge alert button"), style: .default) { _ in
                    if let pxUrl = URL(string: "https://popopxchat.com/crowdfunding") {
                        UIApplication.shared.open(pxUrl)
                    }
                  },
                  okAlertAction ]
            }
        } else {
            // POPOPX: supporter, legend and unknown types use the supporter wording
            let pxSupportsText =
                if badge.status == .expired {
                    String.localizedStringWithFormat(NSLocalizedString("%1$@ supported POPOPX Chat. The badge expired on %2$@.", comment: "badge alert"), name, badge.badge.badgeExpiry.formatted(date: .abbreviated, time: .omitted))
                } else {
                    String.localizedStringWithFormat(NSLocalizedString("%@ supports POPOPX Chat.", comment: "badge alert"), name)
                }
            if noShownBadge() {
                showAlert(pxTitle, message: pxSupportsText) {
                    [ supportPopopxAlertAction, okAlertAction ]
                }
            } else {
                showAlert(pxTitle, message: pxSupportsText)
            }
        }
    }
}

// MARK: - POPOPX

private let pxComponentTag = "PXNameBadge"

// verbatim for an unknown type: it is the service's string, and must not be looked up as a localised key
func badgeTypeName(_ t: BadgeType) -> String {
    switch t {
    case .supporter: NSLocalizedString("Supporter", comment: "badge type")
    case .legend: NSLocalizedString("Legend", comment: "badge type")
    case .investor: NSLocalizedString("Investor", comment: "badge type")
    case let .unknown(s): s
    }
}
