#!/usr/bin/swift
// Generates Assets.xcassets/AppIcon.appiconset/icon_1024.png
// Run from repo root: swift Scripts/generate_icon.swift

import AppKit

let side = 1024
let sz   = CGFloat(side)
let cs   = CGColorSpaceCreateDeviceRGB()

// RGB context — no alpha channel, exactly 1024×1024, display-scale-independent.
guard let ctx = CGContext(
    data: nil, width: side, height: side,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue).rawValue
) else { print("CGContext init failed"); exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

// ── Background gradient (dark navy → midnight blue, bottom to top) ────────
let bgGrad = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 0.039, green: 0.047, blue: 0.078, alpha: 1),
        CGColor(red: 0.082, green: 0.118, blue: 0.337, alpha: 1),
    ] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bgGrad,
    start: .init(x: sz/2, y: 0), end: .init(x: sz/2, y: sz), options: [])

// ── Soft glow behind moon ─────────────────────────────────────────────────
ctx.setBlendMode(.screen)
let glowGrad = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 0.29, green: 0.44, blue: 1.0, alpha: 0.30),
        CGColor(red: 0.29, green: 0.44, blue: 1.0, alpha: 0.00),
    ] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glowGrad,
    startCenter: .init(x: 490, y: 520), startRadius: 0,
    endCenter:   .init(x: 490, y: 520), endRadius: 310, options: [])
ctx.setBlendMode(.normal)

// ── Crescent moon (even-odd fill) ─────────────────────────────────────────
let outerR = 210.0; let cx = 460.0; let cy = 510.0
let innerR = 168.0; let ix = 548.0; let iy = 568.0

let moon = NSBezierPath()
moon.appendOval(in: .init(x: cx-outerR, y: cy-outerR, width: outerR*2, height: outerR*2))
moon.appendOval(in: .init(x: ix-innerR, y: iy-innerR, width: innerR*2, height: innerR*2))
moon.windingRule = .evenOdd
NSColor(red: 0.88, green: 0.92, blue: 1.00, alpha: 1.0).setFill()
moon.fill()

// ── Stars ─────────────────────────────────────────────────────────────────
for (x, y, r, a) in [(735.0,665.0,8.0,1.00),(695.0,595.0,4.5,0.80),
                     (775.0,590.0,5.5,0.85),(755.0,725.0,5.0,0.70),
                     (685.0,725.0,3.5,0.60),(765.0,535.0,3.0,0.55),(310.0,685.0,4.0,0.50)] {
    NSColor(white: 1, alpha: a).setFill()
    NSBezierPath(ovalIn: .init(x: x-r, y: y-r, width: r*2, height: r*2)).fill()
}

NSGraphicsContext.restoreGraphicsState()

// ── Write PNG ─────────────────────────────────────────────────────────────
guard let cgImage = ctx.makeImage() else { print("makeImage failed"); exit(1) }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let png = rep.representation(using: .png, properties: [:]) else {
    print("PNG encoding failed"); exit(1)
}
let dest = URL(fileURLWithPath: "Assets.xcassets/AppIcon.appiconset/icon_1024.png")
try! png.write(to: dest)
print("✓  \(dest.path)  (\(png.count / 1024) KB)")
