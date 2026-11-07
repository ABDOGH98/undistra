// Draws the Undistra app icon and menu-bar icons.
// Run from the project folder:  swift Branding/render-icon.swift
//
// Concept: a "U" (for Undistra) holding one glowing dot (your single focus),
// with faded dots drifting away outside it (the distractions).

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

// Brand colors
let coral = 0xFF7A45 as UInt32, pink = 0xFF2D7A as UInt32, violet = 0x7A3CF0 as UInt32

// Geometry on a 1024 × 1024 canvas, measured from the top-left.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)   // macOS icon grid
let tileRadius: CGFloat = 185
let dotCenter = CGPoint(x: 512, y: 545)
let dotRadius: CGFloat = 64
let particles: [(CGPoint, CGFloat)] = [
    (CGPoint(x: 236, y: 268), 17), (CGPoint(x: 796, y: 240), 23), (CGPoint(x: 846, y: 430), 12),
    (CGPoint(x: 192, y: 478), 11), (CGPoint(x: 812, y: 700), 15),
]

func uPath() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 352, y: 300))
    path.addLine(to: CGPoint(x: 352, y: 560))
    path.addArc(center: CGPoint(x: 512, y: 560), radius: 160, startAngle: .pi, endAngle: 0, clockwise: true)
    path.addLine(to: CGPoint(x: 672, y: 300))
    return path
}

func makeContext(_ px: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 1, y: -1) // draw top-down
    ctx.interpolationQuality = .high
    return ctx
}

func renderAppIcon(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    let s = CGFloat(px) / 1024 // shadows are in device pixels, so scale them by hand
    let squircle = CGPath(roundedRect: tile, cornerWidth: tileRadius, cornerHeight: tileRadius, transform: nil)

    // Drop shadow under the tile
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 24 * s, color: color(0x000000, 0.35))
    ctx.addPath(squircle)
    ctx.setFillColor(color(pink))
    ctx.fillPath()
    ctx.restoreGState()

    // Gradient background
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let bg = CGGradient(colorsSpace: srgb, colors: [color(coral), color(pink), color(violet)] as CFArray,
                        locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 140, y: 100), end: CGPoint(x: 884, y: 924), options: [])

    // Soft light from the top
    let highlight = CGGradient(colorsSpace: srgb, colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)] as CFArray,
                               locations: [0, 1])!
    ctx.drawLinearGradient(highlight, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 560), options: [])

    // Glow around the focus dot
    let glow = CGGradient(colorsSpace: srgb, colors: [color(0xFFFFFF, 0.38), color(0xFFFFFF, 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: dotCenter, startRadius: 0, endCenter: dotCenter, endRadius: 270, options: [])

    // Distractions drifting away (left out at tiny sizes, where they'd just look like noise)
    if px >= 64 {
        for (center, radius) in particles {
            ctx.setFillColor(color(0xFFFFFF, 0.42))
            ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
    }
    ctx.restoreGState()

    // The U
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6 * s), blur: 18 * s, color: color(0x3A0A4A, 0.25))
    ctx.addPath(uPath())
    ctx.setStrokeColor(white)
    ctx.setLineWidth(px >= 64 ? 92 : 104) // a little bolder at small sizes
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // The focus dot
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 44 * s, color: color(0xFFFFFF, 0.95))
    ctx.setFillColor(white)
    let r = px >= 64 ? dotRadius : dotRadius * 1.15
    ctx.fillEllipse(in: CGRect(x: dotCenter.x - r, y: dotCenter.y - r, width: r * 2, height: r * 2))
    ctx.restoreGState()

    return ctx.makeImage()!
}

/// Black-on-transparent glyph for the menu bar (macOS tints it). `filled` = focus is on.
func renderMenuBarIcon(_ px: Int, filled: Bool) -> CGImage {
    let ctx = makeContext(px)
    ctx.translateBy(x: 512, y: 512)
    ctx.scaleBy(x: 1.55, y: 1.55)  // the glyph fills the canvas better than the icon tile does
    ctx.translateBy(x: -512, y: -532)
    ctx.addPath(uPath())
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
    ctx.setLineWidth(96)
    ctx.setLineCap(.round)
    ctx.strokePath()
    let r: CGFloat = 58 // smaller and higher than in the app icon, so it stays clear of the U at 18 pt
    let dot = CGRect(x: 512 - r, y: 505 - r, width: r * 2, height: r * 2)
    if filled {
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fillEllipse(in: dot)
    } else {
        ctx.setLineWidth(30)
        ctx.strokeEllipse(in: dot.insetBy(dx: 15, dy: 15))
    }
    return ctx.makeImage()!
}

func save(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let assets = "Undistra/Assets.xcassets"

// App icon: every size macOS asks for
let iconSizes: [(points: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                                               (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [String] = []
for (points, scale) in iconSizes {
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    save(renderAppIcon(points * scale), to: "\(assets)/AppIcon.appiconset/\(name)")
    images.append("""
        { "filename" : "\(name)", "idiom" : "mac", "scale" : "\(scale)x", "size" : "\(points)x\(points)" }
    """)
}
try! """
{
  "images" : [
\(images.joined(separator: ",\n"))
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""".write(toFile: "\(assets)/AppIcon.appiconset/Contents.json", atomically: true, encoding: .utf8)

// Menu-bar icons (template images, 18 pt)
for (name, filled) in [("MenuBarIconOn", true), ("MenuBarIconOff", false)] {
    let dir = "\(assets)/\(name).imageset"
    save(renderMenuBarIcon(18, filled: filled), to: "\(dir)/\(name).png")
    save(renderMenuBarIcon(36, filled: filled), to: "\(dir)/\(name)@2x.png")
    try! """
    {
      "images" : [
        { "filename" : "\(name).png", "idiom" : "mac", "scale" : "1x" },
        { "filename" : "\(name)@2x.png", "idiom" : "mac", "scale" : "2x" }
      ],
      "info" : { "author" : "xcode", "version" : 1 },
      "properties" : { "template-rendering-intent" : "template" }
    }
    """.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
}

// Large copy for the website, App Store and social media
save(renderAppIcon(1024), to: "Branding/undistra-icon-1024.png")
print("Icons written.")
