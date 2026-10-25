// Draws the SimplePJ app icon and writes Resources/AppIcon.icns. Usage: swift Scripts/make-icon.swift
import AppKit

func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func drawIcon(size: Int) -> Data {
    let s = CGFloat(size) / 1024
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: s, y: s)

    // macOS icon grid: 824 pt rounded square centred in 1024
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * s), blur: 28 * s, color: color(0x000000, 0.48))
    ctx.addPath(shape)
    ctx.setFillColor(color(0x14171C))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let bg = CGGradient(colorsSpace: space, colors: [color(0x222731), color(0x0E1014)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])

    // Subtle concentric stage grid arcs
    for r in [260.0, 420.0, 580.0] {
        ctx.setStrokeColor(color(0xFFFFFF, 0.045))
        ctx.setLineWidth(5)
        ctx.strokeEllipse(in: CGRect(x: 340 - r, y: 512 - r, width: r * 2, height: r * 2))
    }

    // Luminous projection beam cone from lens (x=420, y=512) to stage screen (x=805)
    ctx.saveGState()
    let beamPath = CGMutablePath()
    beamPath.move(to: CGPoint(x: 416, y: 472))
    beamPath.addLine(to: CGPoint(x: 800, y: 256))
    beamPath.addLine(to: CGPoint(x: 800, y: 768))
    beamPath.addLine(to: CGPoint(x: 416, y: 552))
    beamPath.closeSubpath()
    ctx.addPath(beamPath)
    ctx.clip()
    let beamGrad = CGGradient(
        colorsSpace: space,
        colors: [color(0xFFB454, 0.72), color(0xFFB454, 0.22), color(0x9ECE6A, 0.06)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    ctx.drawLinearGradient(beamGrad, start: CGPoint(x: 416, y: 512), end: CGPoint(x: 800, y: 512), options: [])
    ctx.restoreGState()

    // Inner rays inside the beam
    ctx.setStrokeColor(color(0xFFB454, 0.28))
    ctx.setLineWidth(6)
    ctx.setLineCap(.round)
    for targetY in [340.0, 512.0, 684.0] {
        ctx.move(to: CGPoint(x: 424, y: 512))
        ctx.addLine(to: CGPoint(x: 785, y: targetY))
        ctx.strokePath()
    }

    // Stage projection screen bar on the right
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 24 * s, color: color(0x9ECE6A, 0.85))
    ctx.setStrokeColor(color(0x9ECE6A))
    ctx.setLineWidth(20)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 804, y: 262))
    ctx.addLine(to: CGPoint(x: 804, y: 762))
    ctx.strokePath()
    ctx.restoreGState()

    // Projector chassis on the left
    let chassisRect = CGRect(x: 188, y: 418, width: 204, height: 188)
    let chassisPath = CGPath(roundedRect: chassisRect, cornerWidth: 34, cornerHeight: 34, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8 * s), blur: 20 * s, color: color(0x000000, 0.6))
    ctx.addPath(chassisPath)
    ctx.setFillColor(color(0x252B37))
    ctx.fillPath()
    ctx.setStrokeColor(color(0xFFFFFF, 0.16))
    ctx.setLineWidth(6)
    ctx.addPath(chassisPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Cooling vents on projector body
    ctx.setStrokeColor(color(0x111317, 0.8))
    ctx.setLineWidth(8)
    ctx.setLineCap(.round)
    for vx in [232.0, 260.0, 288.0] {
        ctx.move(to: CGPoint(x: vx, y: 458))
        ctx.addLine(to: CGPoint(x: vx, y: 566))
        ctx.strokePath()
    }

    // Status LED on projector body (alive green)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 14 * s, color: color(0x9ECE6A, 0.9))
    ctx.setFillColor(color(0x9ECE6A))
    ctx.fillEllipse(in: CGRect(x: 332, y: 540, width: 24, height: 24))
    ctx.restoreGState()

    // Projector optical lens barrel
    let barrelRect = CGRect(x: 376, y: 454, width: 52, height: 116)
    let barrelPath = CGPath(roundedRect: barrelRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 28 * s, color: color(0xFFB454, 0.9))
    ctx.addPath(barrelPath)
    ctx.setFillColor(color(0xFFB454))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.restoreGState()
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let resources = root.appendingPathComponent("Resources")
let iconset = fm.temporaryDirectory.appendingPathComponent("SimplePJ-\(UUID().uuidString).iconset")
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
try! fm.createDirectory(at: resources, withIntermediateDirectories: true)
for (name, size) in [
    ("16x16", 16), ("16x16@2x", 32),
    ("32x32", 32), ("32x32@2x", 64),
    ("128x128", 128), ("128x128@2x", 256),
    ("256x256", 256), ("256x256@2x", 512),
    ("512x512", 512), ("512x512@2x", 1024),
] {
    try! drawIcon(size: size).write(to: iconset.appendingPathComponent("icon_\(name).png"))
}
try! drawIcon(size: 1024).write(to: resources.appendingPathComponent("AppIcon.png"))
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try! task.run()
task.waitUntilExit()
try? fm.removeItem(at: iconset)
print(task.terminationStatus == 0 ? "wrote \(resources.path)/AppIcon.icns" : "iconutil failed")
exit(task.terminationStatus)
