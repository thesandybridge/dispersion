#!/usr/bin/env swift
import CoreGraphics
import Foundation
#if canImport(ImageIO)
import ImageIO
#endif

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }

let s = CGFloat(size)
let cx = s / 2
let cy = s / 2

// Background gradient — matching splash (ink → pine → backgroundDeep)
let bgColors: [CGFloat] = [
    0.055, 0.102, 0.075, 1.0,  // ink-ish top-left
    0.043, 0.239, 0.180, 1.0,  // pine mid
    0.027, 0.051, 0.039, 1.0,  // backgroundDeep bottom-right
]
if let gradient = CGGradient(colorSpace: cs, colorComponents: bgColors, locations: [0, 0.5, 1], count: 3) {
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
}

// Dispersion rings — 5 concentric circles like the splash
let ringColor: (CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) = { i in
    let base: CGFloat = 0.08 + i * 0.06
    return (0.663, 0.820, 0.557, base) // primary green (#a9d18e) at varying opacity
}

let ringRadii: [CGFloat] = [340, 280, 220, 160, 100]
for (i, r) in ringRadii.enumerated() {
    let c = ringColor(CGFloat(i))
    ctx.setStrokeColor(CGColor(red: c.r, green: c.g, blue: c.b, alpha: c.a))
    ctx.setLineWidth(2.5)
    ctx.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
}

// Innermost filled glow
let glowColors: [CGFloat] = [
    0.663, 0.820, 0.557, 0.12,  // primary green, faint
    0.663, 0.820, 0.557, 0.0,
]
if let glow = CGGradient(colorSpace: cs, colorComponents: glowColors, locations: [0, 1], count: 2) {
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                           endCenter: CGPoint(x: cx, y: cy), endRadius: 120, options: [])
}

// Reticle crosshair — white lines
let reticleColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.6)
ctx.setStrokeColor(reticleColor)
ctx.setLineWidth(4)

// Vertical lines
ctx.move(to: CGPoint(x: cx, y: cy - 80))
ctx.addLine(to: CGPoint(x: cx, y: cy - 20))
ctx.move(to: CGPoint(x: cx, y: cy + 20))
ctx.addLine(to: CGPoint(x: cx, y: cy + 80))

// Horizontal lines
ctx.move(to: CGPoint(x: cx - 80, y: cy))
ctx.addLine(to: CGPoint(x: cx - 20, y: cy))
ctx.move(to: CGPoint(x: cx + 20, y: cy))
ctx.addLine(to: CGPoint(x: cx + 80, y: cy))
ctx.strokePath()

// Center dot — primary green
ctx.setFillColor(CGColor(red: 0.663, green: 0.820, blue: 0.557, alpha: 1.0))
let dotR: CGFloat = 10
ctx.fillEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))

// Outer reticle ring
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.4))
ctx.setLineWidth(3)
ctx.strokeEllipse(in: CGRect(x: cx - 50, y: cy - 50, width: 100, height: 100))

// Save
guard let image = ctx.makeImage() else { exit(1) }
let outputPath = "Dispersion/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png"
guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outputPath) as CFURL, "public.png" as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("Icon saved")
