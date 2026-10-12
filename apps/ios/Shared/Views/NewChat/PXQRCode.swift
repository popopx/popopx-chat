//
//  QRCode.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 30/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/navigation.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import CoreImage.CIFilterBuiltins
import POPOPXSwitch

// Reusable CIContext avoids expensive re-creation on each QR generation
private let sharedCIContext = CIContext()

// POPOPX: default brand tint for QR codes
private let pxDefaultTint = UIColor(red: 0.023, green: 0.176, blue: 0.337, alpha: 1)

struct PXMutableQRCode: View {
    @Binding var uri: String
    var small: Bool = false
    var withLogo: Bool = true
    var tintColor = pxDefaultTint

    var body: some View {
        QRCode(uri: uri, small: small, withLogo: withLogo, tintColor: tintColor)
            .id("popopx-qrcode-view-for-\(uri)")
        .popopxBranded()
    }
}

struct PXLinkQRCode: View {
    let link: CreatedConnLink
    @Binding var short: Bool
    var onShare: (() -> Void)? = nil

    var body: some View {
        QRCode(uri: link.popopxChatUri(short: short), small: short && link.connShortLink != nil, onShare: onShare)
    }
}

struct PXContactLinkQRCode: View {
    let uri: String
    var withLogo: Bool = true
    var tintColor = pxDefaultTint
    var onShare: (() -> Void)? = nil

    // POPOPX: use smaller QR for short URIs
    private var isShortURI: Bool { uri.count < 200 }

    var body: some View {
        QRCode(uri: popopxChatLink(uri), small: isShortURI, withLogo: withLogo, tintColor: tintColor, onShare: onShare)
    }
}

private let smallQRRatio: CGFloat = 0.63

// POPOPX: logo sizing ratios
private let pxSmallLogoRatio: CGFloat = 0.195
private let pxNormalLogoRatio: CGFloat = 0.16
private let pxLogoMarginFactor: CGFloat = 0.005

struct QRCode: View {
    let uri: String
    var small: Bool = false
    var withLogo: Bool = true
    var tintColor = pxDefaultTint
    var onShare: (() -> Void)? = nil
    @State private var image: UIImage? = nil
    @State private var makeScreenshotFunc: () -> Void = {}
    @State private var width: CGFloat = .infinity
    @Environment(\.displayScale) private var displayScale: CGFloat

    // POPOPX: compute logo dimensions based on view size
    private func logoSize(for w: CGFloat) -> CGFloat {
        w * (small ? pxSmallLogoRatio : pxNormalLogoRatio)
    }

    private func logoMargin(for w: CGFloat) -> CGFloat {
        w * pxLogoMarginFactor
    }

    var body: some View {
        ZStack {
            if let image = image {
                qrCodeImage(image)
                    .frame(width: width.isFinite ? width : nil, height: width.isFinite ? width : nil)
                GeometryReader { g in
                    let w = g.size.width * (small ? smallQRRatio : 1)
                    let l = logoSize(for: w)
                    let m = logoMargin(for: w)
                    ZStack {
                        if withLogo {
                            Image("logo-light")
                            .resizable()
                            .scaledToFit()
                            .frame(width: l, height: l)
                            .frame(width: l + m, height: l + m)
                            .background(.white)
                            .clipShape(Circle())
                        }
                    }
                    .onAppear {
                        width = w
                        makeScreenshotFunc = {
                            let exportSize = QRCode.pxScreenshotExportSize / displayScale
                            let size = CGSizeMake(exportSize, exportSize)
                            showShareSheet(items: [makeScreenshot(g.frame(in: .local).origin, size)])
                            onShare?()
                        }
                    }
                    .frame(width: g.size.width, height: g.size.height)
                }
            } else {
                Color.clear.aspectRatio(small ? 1 / smallQRRatio : 1, contentMode: .fit)
            }
        }
        .onTapGesture(perform: makeScreenshotFunc)
        .task { image = await generateImage(uri, tintColor: tintColor, errorLevel: small ? "M" : "L") }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// POPOPX: render QR code image with crisp interpolation
private func qrCodeImage(_ image: UIImage) -> some View {
    Image(uiImage: image)
        .resizable()
        .interpolation(.none) // POPOPX: disable interpolation for sharp QR pixels
        .aspectRatio(1, contentMode: .fit)
        .textSelection(.enabled)
}

// POPOPX: generate QR code with brand tint color
private func generateImage(_ uri: String, tintColor: UIColor, errorLevel: String) async -> UIImage? {
    let context = sharedCIContext
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(uri.utf8)
    filter.correctionLevel = errorLevel

    guard let outputImage = filter.outputImage,
          let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
        return nil
    }

    // POPOPX: replace black with brand tint
    return UIImage(cgImage: cgImage).replaceColor(UIColor.black, tintColor)
}

// POPOPX: screenshot helper for sharing QR codes
extension View {
    func makeScreenshot(_ origin: CGPoint? = nil, _ targetSize: CGSize? = nil) -> UIImage {
        let controller = UIHostingController(rootView: self.edgesIgnoringSafeArea(.all))
        let computedSize = targetSize ?? controller.view.intrinsicContentSize
        let view = controller.view

        // POPOPX: set bounds and clear background for clean capture
        view?.bounds = CGRect(origin: origin ?? .zero, size: computedSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: computedSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

struct QRCode_Previews: PreviewProvider {
    static var previews: some View {
        QRCode(uri: "https://popopxchat.com/invitation#/?v=1&smp=smp%3A%2F%2Fu2dS9sG8nMNURyZwqASV4yROM28Er0luVTx5X1CsMrU%3D%40smp4.popopxchat.com%2FFe5ICmvrm4wkrr6X1LTMii-lhBqLeB76%23MCowBQYDK2VuAyEAdhZZsHpuaAk3Hh1q0uNb_6hGTpuwBIrsp2z9U2T0oC0%3D&e2e=v%3D1%26x3dh%3DMEIwBQYDK2VvAzkAcz6jJk71InuxA0bOX7OUhddfB8Ov7xwQIlIDeXBRZaOntUU4brU5Y3rBzroZBdQJi0FKdtt_D7I%3D%2CMEIwBQYDK2VvAzkA-hDvk1duBi1hlOr08VWSI-Ou4JNNSQjseY69QyKm7Kgg1zZjbpGfyBqSZ2eqys6xtoV4ZtoQUXQ%3D")
    }
}

// MARK: - POPOPX
extension QRCode {
    static let pxComponentTag: String = "PXQRCode"
    static let pxQRTintRed: CGFloat = 0.023
    static let pxQRTintGreen: CGFloat = 0.176
    static let pxQRTintBlue: CGFloat = 0.337
    static let pxSmallQRRatio: CGFloat = 0.63
    static let pxScreenshotExportSize: CGFloat = 1024
}
