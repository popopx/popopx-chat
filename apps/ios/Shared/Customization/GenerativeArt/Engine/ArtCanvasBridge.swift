// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import CoreGraphics
import UIKit
import JavaScriptCore

/// Bridges JavaScript drawing commands to a CoreGraphics bitmap context.
/// Provides a deterministic, headless Canvas implementation for Art Blocks–style generators.
final class ArtCanvasBridge {
    let bitmapContext: CGContext?
    let width: Int
    let height: Int

    // Current path state
    private var currentPath: CGMutablePath = CGMutablePath()
    private var fillColor: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 1)
    private var strokeColor: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 1)
    private var lineWidth: CGFloat = 1.0
    private var transform: CGAffineTransform = .identity

    init?(width: Int, height: Int) {
        self.width = width
        self.height = height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        self.bitmapContext = ctx
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
    }

    // MARK: - JS Bridge Registration

    private final class WeakBox {
        weak var value: ArtCanvasBridge?
        init(_ value: ArtCanvasBridge) { self.value = value }
    }

    func register(with jsContext: JSContext) {
        guard let bitmapContext = bitmapContext else { return }
        let box = WeakBox(self)

        // Path operations
        jsContext.setObject({ (args: [JSValue]) in
            guard let bridge = box.value, args.count >= 2 else { return }
            let x = args[0].toDouble(), y = args[1].toDouble()
            bridge.currentPath.move(to: CGPoint(x: x, y: y), transform: bridge.transform)
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "moveToPoint" as NSString)

        jsContext.setObject({ (args: [JSValue]) in
            guard let bridge = box.value, args.count >= 2 else { return }
            let x = args[0].toDouble(), y = args[1].toDouble()
            bridge.currentPath.addLine(to: CGPoint(x: x, y: y), transform: bridge.transform)
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "addLineToPoint" as NSString)

        jsContext.setObject({ (args: [JSValue]) in
            guard let bridge = box.value, args.count >= 6 else { return }
            let cp1x = args[0].toDouble(), cp1y = args[1].toDouble()
            let cp2x = args[2].toDouble(), cp2y = args[3].toDouble()
            let x = args[4].toDouble(), y = args[5].toDouble()
            bridge.currentPath.addCurve(
                to: CGPoint(x: x, y: y),
                control1: CGPoint(x: cp1x, y: cp1y),
                control2: CGPoint(x: cp2x, y: cp2y),
                transform: bridge.transform
            )
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "addCurveToPoint" as NSString)

        jsContext.setObject({ (_: [JSValue]) in
            box.value?.currentPath.closeSubpath()
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "closePath" as NSString)

        jsContext.setObject({ (_: [JSValue]) in
            box.value?.currentPath = CGMutablePath()
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "beginPath" as NSString)

        // Drawing
        jsContext.setObject({ (_: [JSValue]) in
            guard let bridge = box.value else { return }
            bitmapContext.addPath(bridge.currentPath)
            let color = CGColor(
                red: bridge.fillColor.0,
                green: bridge.fillColor.1,
                blue: bridge.fillColor.2,
                alpha: bridge.fillColor.3
            )
            bitmapContext.setFillColor(color)
            bitmapContext.fillPath()
            bridge.currentPath = CGMutablePath()
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "fillPath" as NSString)

        jsContext.setObject({ (_: [JSValue]) in
            guard let bridge = box.value else { return }
            bitmapContext.addPath(bridge.currentPath)
            let color = CGColor(
                red: bridge.strokeColor.0,
                green: bridge.strokeColor.1,
                blue: bridge.strokeColor.2,
                alpha: bridge.strokeColor.3
            )
            bitmapContext.setStrokeColor(color)
            bitmapContext.setLineWidth(bridge.lineWidth)
            bitmapContext.strokePath()
            bridge.currentPath = CGMutablePath()
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "strokePath" as NSString)

        // Color setters
        jsContext.setObject({ (args: [JSValue]) in
            guard let bridge = box.value, args.count >= 4 else { return }
            bridge.fillColor = (
                CGFloat(args[0].toDouble()),
                CGFloat(args[1].toDouble()),
                CGFloat(args[2].toDouble()),
                CGFloat(args[3].toDouble())
            )
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "setFillColor" as NSString)

        jsContext.setObject({ (args: [JSValue]) in
            guard let bridge = box.value, args.count >= 4 else { return }
            bridge.strokeColor = (
                CGFloat(args[0].toDouble()),
                CGFloat(args[1].toDouble()),
                CGFloat(args[2].toDouble()),
                CGFloat(args[3].toDouble())
            )
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "setStrokeColor" as NSString)

        jsContext.setObject({ (args: [JSValue]) in
            guard let bridge = box.value, let w = args.first?.toDouble() else { return }
            bridge.lineWidth = CGFloat(w)
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "setLineWidth" as NSString)

        // Rect operations
        jsContext.setObject({ (args: [JSValue]) in
            guard let bridge = box.value, args.count >= 4 else { return }
            let x = args[0].toDouble(), y = args[1].toDouble()
            let w = args[2].toDouble(), h = args[3].toDouble()
            let rect = CGRect(x: x, y: y, width: w, height: h)
            let color = CGColor(
                red: bridge.fillColor.0,
                green: bridge.fillColor.1,
                blue: bridge.fillColor.2,
                alpha: bridge.fillColor.3
            )
            bitmapContext.setFillColor(color)
            bitmapContext.fill(rect)
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "fillRect" as NSString)

        jsContext.setObject({ (args: [JSValue]) in
            guard args.count >= 4 else { return }
            let x = args[0].toDouble(), y = args[1].toDouble()
            let w = args[2].toDouble(), h = args[3].toDouble()
            let rect = CGRect(x: x, y: y, width: w, height: h)
            bitmapContext.clear(rect)
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "clearRect" as NSString)

        // Circle
        jsContext.setObject({ (args: [JSValue]) in
            guard let bridge = box.value, args.count >= 3 else { return }
            let x = args[0].toDouble(), y = args[1].toDouble()
            let r = args[2].toDouble()
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            let path = CGPath(ellipseIn: rect, transform: nil)
            bitmapContext.addPath(path)
            let color = CGColor(
                red: bridge.fillColor.0,
                green: bridge.fillColor.1,
                blue: bridge.fillColor.2,
                alpha: bridge.fillColor.3
            )
            bitmapContext.setFillColor(color)
            bitmapContext.fillPath()
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "fillCircle" as NSString)

        // Transform
        jsContext.setObject({ (args: [JSValue]) in
            guard let bridge = box.value, args.count >= 2 else { return }
            let tx = args[0].toDouble(), ty = args[1].toDouble()
            bridge.transform = bridge.transform.translatedBy(x: tx, y: ty)
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "translate" as NSString)

        jsContext.setObject({ (args: [JSValue]) in
            guard let bridge = box.value, let angle = args.first?.toDouble() else { return }
            bridge.transform = bridge.transform.rotated(by: angle)
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "rotate" as NSString)

        jsContext.setObject({ (args: [JSValue]) in
            guard let bridge = box.value, args.count >= 2 else { return }
            let sx = args[0].toDouble(), sy = args[1].toDouble()
            bridge.transform = bridge.transform.scaledBy(x: sx, y: sy)
        } as @convention(block) ([JSValue]) -> Void, forKeyedSubscript: "scale" as NSString)

        // Canvas dimensions
        jsContext.setObject(Double(width), forKeyedSubscript: "__WIDTH__" as NSString)
        jsContext.setObject(Double(height), forKeyedSubscript: "__HEIGHT__" as NSString)
    }

    // MARK: - Export

    func toUIImage() -> UIImage? {
        guard let bitmapContext = bitmapContext, let cgImage = bitmapContext.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func reset() {
        bitmapContext?.clear(CGRect(x: 0, y: 0, width: width, height: height))
        currentPath = CGMutablePath()
        fillColor = (0, 0, 0, 1)
        strokeColor = (0, 0, 0, 1)
        lineWidth = 1.0
        transform = .identity
    }
}
