#!/usr/bin/swift
// Generates Assets.xcassets/AppIcon.appiconset/icon_1024.png
// Run from repo root: swift Scripts/generate_icon.swift

import AppKit

let size = 1024.0
let img  = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext
let cs  = CGColorSpaceCreateDeviceRGB()

// ── Background gradient (dark navy → midnight blue, bottom to top) ────────
let bgGrad = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 0.039, green: 0.047, blue: 0.078, alpha: 1),
        CGColor(red: 0.082, green: 0.118, blue: 0.337, alpha: 1),
    ] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(bgGrad,
    start: .init(x: size/2, y: 0),
    end:   .init(x: size/2, y: size),
    options: [])

// ── Soft glow behind moon (screen blend) ─────────────────────────────────
ctx.setBlendMode(.screen)
let glowGrad = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 0.29, green: 0.44, blue: 1.0, alpha: 0.30),
        CGColor(red: 0.29, green: 0.44, blue: 1.0, alpha: 0.00),
    ] as CFArray,
    locations: [0, 1])!
ctx.drawRadialGradient(glowGrad,
    startCenter: .init(x: 490, y: 520), startRadius: 0,
    endCenter:   .init(x: 490, y: 520), endRadius:   310,
    options: [])
ctx.setBlendMode(.normal)

// ── Crescent moon (even-odd fill) ─────────────────────────────────────────
//   Outer circle centred at (460, 510), radius 210.
//   Inner circle offset upper-right to carve the crescent.
let outerR  = 210.0;  let cx = 460.0;  let cy = 510.0
let innerR  = 168.0;  let ix = 548.0;  let iy = 568.0

let moon = NSBezierPath()
moon.appendOval(in: .init(x: cx-outerR, y: cy-outerR, width: outerR*2, height: outerR*2))
moon.appendOval(in: .init(x: ix-innerR, y: iy-innerR, width: innerR*2, height: innerR*2))
moon.windingRule = .evenOdd
NSColor(red: 0.88, green: 0.92, blue: 1.00, alpha: 1.0).setFill()
moon.fill()

// ── Stars ─────────────────────────────────────────────────────────────────
//   (x, y, radius, alpha)  — clustered upper-right of moon
let stars: [(Double, Double, Double, Double)] = [
    (735, 665, 8.0, 1.00),
    (695, 595, 4.5, 0.80),
    (775, 590, 5.5, 0.85),
    (755, 725, 5.0, 0.70),
    (685, 725, 3.5, 0.60),
    (765, 535, 3.0, 0.55),
    (310, 685, 4.0, 0.50),
]
for (x, y, r, a) in stars {
    NSColor(white: 1, alpha: a).setFill()
    NSBezierPath(ovalIn: .init(x: x-r, y: y-r, width: r*2, height: r*2)).fill()
}

img.unlockFocus()

// ── Write PNG ─────────────────────────────────────────────────────────────
let tiff = img.tiffRepresentation!
let bmp  = NSBitmapImageRep(data: tiff)!
let png  = bmp.representation(using: .png, properties: [:])!

let dest = URL(fileURLWithPath: "Assets.xcassets/AppIcon.appiconset/icon_1024.png")
try! png.write(to: dest)
print("✓  \(dest.path)  (\(png.count / 1024) KB)")
