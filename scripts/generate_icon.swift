#!/usr/bin/env swift
// Renders the Mattery app icon at all sizes required by AppIcon.appiconset.

import AppKit
import CoreGraphics
import Foundation

let bodyFill   = CGColor(red: 0.85, green: 0.94, blue: 0.95, alpha: 1.0)
let strokeC    = CGColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1.0)
let boltFill   = CGColor(red: 1.00, green: 0.84, blue: 0.20, alpha: 1.0)
let barFill    = CGColor(red: 0.36, green: 0.83, blue: 0.77, alpha: 1.0)
let bgFill     = CGColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)

func renderIcon(pixels: Int) -> Data {
    let s = CGFloat(pixels)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create CGContext")
    }

    // Top-left origin to make manual coordinates intuitive.
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    // Soft light background with rounded corners (macOS expects squircle).
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
    ctx.addPath(bgPath)
    ctx.setFillColor(bgFill)
    ctx.fillPath()

    let stroke = max(s * 0.020, 1.5)
    ctx.setLineWidth(stroke)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)

    // Battery terminal cap on top.
    let cap = CGRect(x: s * 0.405, y: s * 0.115, width: s * 0.19, height: s * 0.06)
    let capPath = CGPath(roundedRect: cap, cornerWidth: s * 0.018, cornerHeight: s * 0.018, transform: nil)
    ctx.addPath(capPath)
    ctx.setFillColor(bodyFill)
    ctx.fillPath()
    ctx.addPath(capPath)
    ctx.setStrokeColor(strokeC)
    ctx.strokePath()

    // Right-side small terminal bump.
    let notch = CGRect(x: s * 0.835, y: s * 0.475, width: s * 0.045, height: s * 0.07)
    let notchPath = CGPath(roundedRect: notch, cornerWidth: s * 0.012, cornerHeight: s * 0.012, transform: nil)
    ctx.addPath(notchPath)
    ctx.setFillColor(bodyFill)
    ctx.fillPath()
    ctx.addPath(notchPath)
    ctx.setStrokeColor(strokeC)
    ctx.strokePath()

    // Battery body.
    let body = CGRect(x: s * 0.135, y: s * 0.165, width: s * 0.730, height: s * 0.720)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: s * 0.060, cornerHeight: s * 0.060, transform: nil)
    ctx.addPath(bodyPath)
    ctx.setFillColor(bodyFill)
    ctx.fillPath()
    ctx.addPath(bodyPath)
    ctx.setStrokeColor(strokeC)
    ctx.strokePath()

    // Lightning bolt (centered in upper-half of body).
    // SVG-derived path scaled into icon coordinates.
    let boltPoints: [(CGFloat, CGFloat)] = [
        (13.0,  2.0),
        ( 3.0, 14.0),
        (12.0, 14.0),
        (11.0, 22.0),
        (21.0, 10.0),
        (13.0, 10.0),
        (14.0,  2.0),
    ]
    // Bolt fits a 24x24 SVG box. Map to a region centered around (0.50, 0.42) with height ~0.34.
    let boltHeight: CGFloat = 0.34
    let scale = boltHeight / 24.0
    let tx: CGFloat = 0.50 - 12.0 * scale
    let ty: CGFloat = 0.42 - 12.0 * scale
    let bolt = CGMutablePath()
    for (i, p) in boltPoints.enumerated() {
        let pt = CGPoint(x: (p.0 * scale + tx) * s, y: (p.1 * scale + ty) * s)
        if i == 0 { bolt.move(to: pt) } else { bolt.addLine(to: pt) }
    }
    bolt.closeSubpath()
    ctx.addPath(bolt)
    ctx.setFillColor(boltFill)
    ctx.fillPath()
    ctx.addPath(bolt)
    ctx.setStrokeColor(strokeC)
    ctx.strokePath()

    // Two teal level bars in the lower half of the body.
    let barX1: CGFloat = s * 0.22
    let barX2: CGFloat = s * 0.78
    let barH: CGFloat  = s * 0.085
    let barTops: [CGFloat] = [s * 0.625, s * 0.760]
    for top in barTops {
        let r = CGRect(x: barX1, y: top, width: barX2 - barX1, height: barH)
        let p = CGPath(roundedRect: r, cornerWidth: s * 0.015, cornerHeight: s * 0.015, transform: nil)
        ctx.addPath(p)
        ctx.setFillColor(barFill)
        ctx.fillPath()
        ctx.addPath(p)
        ctx.setStrokeColor(strokeC)
        ctx.strokePath()
    }

    guard let cg = ctx.makeImage() else { fatalError("Failed to make image") }
    let bitmap = NSBitmapImageRep(cgImage: cg)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG")
    }
    return png
}

let outDir = URL(fileURLWithPath: "Mattery/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

let targets: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, name) in targets {
    let data = renderIcon(pixels: size)
    let url = outDir.appendingPathComponent(name)
    try data.write(to: url)
    print("wrote \(name) (\(size)x\(size), \(data.count) bytes)")
}
