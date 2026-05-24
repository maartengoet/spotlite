import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: swift generate_app_icon.swift <output.icns>\n".utf8))
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = outputURL.deletingLastPathComponent().appendingPathComponent("Spotlite.iconset")
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2)
]

for variant in variants {
    let pixels = variant.points * variant.scale
    let fileName = variant.scale == 1
        ? "icon_\(variant.points)x\(variant.points).png"
        : "icon_\(variant.points)x\(variant.points)@2x.png"
    let image = renderIcon(size: pixels)
    try writePNG(image: image, to: iconsetURL.appendingPathComponent(fileName))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

try? fileManager.removeItem(at: iconsetURL)

guard process.terminationStatus == 0 else {
    exit(process.terminationStatus)
}

func renderIcon(size: Int) -> NSImage {
    let edge = CGFloat(size)
    let image = NSImage(size: NSSize(width: edge, height: edge))

    image.lockFocus()
    defer { image.unlockFocus() }

    let canvas = CGRect(x: 0, y: 0, width: edge, height: edge)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = edge * 0.055
    let backgroundRect = canvas.insetBy(dx: inset, dy: inset)
    let cornerRadius = edge * 0.215
    let backgroundPath = NSBezierPath(
        roundedRect: backgroundRect,
        xRadius: cornerRadius,
        yRadius: cornerRadius
    )

    NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.14, alpha: 1),
        NSColor(calibratedRed: 0.15, green: 0.18, blue: 0.23, alpha: 1)
    ])?.draw(in: backgroundPath, angle: 135)

    let spotlightCenter = CGPoint(x: edge * 0.40, y: edge * 0.58)
    let spotlightRadius = edge * 0.29
    let glowRect = CGRect(
        x: spotlightCenter.x - spotlightRadius,
        y: spotlightCenter.y - spotlightRadius,
        width: spotlightRadius * 2,
        height: spotlightRadius * 2
    )

    NSColor.systemYellow.withAlphaComponent(0.22).setFill()
    NSBezierPath(ovalIn: glowRect).fill()

    NSColor.systemYellow.withAlphaComponent(0.95).setStroke()
    let ring = NSBezierPath(ovalIn: glowRect.insetBy(dx: edge * 0.025, dy: edge * 0.025))
    ring.lineWidth = max(2, edge * 0.035)
    ring.stroke()

    let caretRect = CGRect(
        x: edge * 0.62,
        y: edge * 0.28,
        width: edge * 0.07,
        height: edge * 0.44
    )
    let caretGlow = caretRect.insetBy(dx: -edge * 0.045, dy: -edge * 0.045)

    NSColor.systemYellow.withAlphaComponent(0.26).setFill()
    NSBezierPath(roundedRect: caretGlow, xRadius: edge * 0.045, yRadius: edge * 0.045).fill()

    NSColor.systemYellow.setFill()
    NSBezierPath(roundedRect: caretRect, xRadius: edge * 0.025, yRadius: edge * 0.025).fill()

    let underlineRect = CGRect(
        x: edge * 0.28,
        y: edge * 0.23,
        width: edge * 0.44,
        height: edge * 0.045
    )
    NSColor.systemBlue.withAlphaComponent(0.85).setFill()
    NSBezierPath(roundedRect: underlineRect, xRadius: edge * 0.02, yRadius: edge * 0.02).fill()

    return image
}

func writePNG(image: NSImage, to url: URL) throws {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }

    try pngData.write(to: url)
}
