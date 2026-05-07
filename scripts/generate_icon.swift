#!/usr/bin/env swift
// Renders the Mattery app icon at all sizes required by AppIcon.appiconset.
// Design goal: stays legible at 16x16 — battery silhouette + dominant bolt.

import AppKit
import CoreGraphics
import Foundation

let bgFill   = CGColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
let bodyFill = CGColor(red: 0.66, green: 0.91, blue: 0.88, alpha: 1.0)
let strokeC  = CGColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1.0)
let boltFill = CGColor(red: 1.00, green: 0.82, blue: 0.18, alpha: 1.0)

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

    // Top-left origin coordinates (y grows downward).
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    // Background squircle — subtle off-white so the icon doesn't blend with macOS Light/Dark Dock.
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                        cornerWidth: s * 0.225, cornerHeight: s * 0.225, transform: nil)
    ctx.addPath(bgPath); ctx.setFillColor(bgFill); ctx.fillPath()

    // Stroke scales with size. Thicker at small sizes for legibility.
    let strokeRatio: CGFloat = pixels <= 32 ? 0.040 : (pixels <= 128 ? 0.030 : 0.024)
    let stroke = max(s * strokeRatio, 1.5)
    ctx.setLineWidth(stroke)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)

    // Battery terminal cap.
    let cap = CGRect(x: s * 0.395, y: s * 0.110, width: s * 0.21, height: s * 0.060)
    let capPath = CGPath(roundedRect: cap, cornerWidth: s * 0.020, cornerHeight: s * 0.020, transform: nil)
    ctx.addPath(capPath); ctx.setFillColor(bodyFill); ctx.fillPath()
    ctx.addPath(capPath); ctx.setStrokeColor(strokeC); ctx.strokePath()

    // Battery body — bigger and more saturated than v1 for stronger silhouette.
    let body = CGRect(x: s * 0.140, y: s * 0.165, width: s * 0.720, height: s * 0.715)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: s * 0.075, cornerHeight: s * 0.075, transform: nil)
    ctx.addPath(bodyPath); ctx.setFillColor(bodyFill); ctx.fillPath()
    ctx.addPath(bodyPath); ctx.setStrokeColor(strokeC); ctx.strokePath()

    // Lightning bolt — much larger, centered in body. SVG-derived 24x24 polygon.
    let boltPoints: [(CGFloat, CGFloat)] = [
        (13.0,  2.0),
        ( 3.0, 14.0),
        (12.0, 14.0),
        (11.0, 22.0),
        (21.0, 10.0),
        (13.0, 10.0),
        (14.0,  2.0),
    ]
    // Bolt height ~58% of icon, centered in body (~y=0.52 of icon).
    let boltHeight: CGFloat = 0.58
    let scale = boltHeight / 24.0
    let tx: CGFloat = 0.50 - 12.0 * scale
    let ty: CGFloat = 0.52 - 12.0 * scale
    let bolt = CGMutablePath()
    for (i, p) in boltPoints.enumerated() {
        let pt = CGPoint(x: (p.0 * scale + tx) * s, y: (p.1 * scale + ty) * s)
        if i == 0 { bolt.move(to: pt) } else { bolt.addLine(to: pt) }
    }
    bolt.closeSubpath()
    ctx.addPath(bolt); ctx.setFillColor(boltFill); ctx.fillPath()
    ctx.addPath(bolt); ctx.setStrokeColor(strokeC); ctx.strokePath()

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
