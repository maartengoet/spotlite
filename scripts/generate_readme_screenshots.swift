#!/usr/bin/env swift

import AppKit

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("docs/screenshots", isDirectory: true)

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

struct DemoCanvas {
    let size = CGSize(width: 1400, height: 900)
    let scale: CGFloat = 2

    func render(_ name: String, drawing: (CGRect) -> Void) throws {
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        drawing(CGRect(origin: .zero, size: size))
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let source = NSBitmapImageRep(data: tiff) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let bitmap else {
            throw CocoaError(.fileWriteUnknown)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)
        source.draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try png.write(to: outputDirectory.appendingPathComponent(name))
    }
}

let canvas = DemoCanvas()

func fill(_ rect: CGRect, _ color: NSColor) {
    color.setFill()
    rect.fill()
}

func stroke(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

func text(_ string: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color
    ]
    NSString(string: string).draw(at: point, withAttributes: attributes)
}

func centeredText(_ string: String, in rect: CGRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight),
        .foregroundColor: color
    ]
    let measured = NSString(string: string).size(withAttributes: attributes)
    let origin = CGPoint(
        x: rect.midX - measured.width / 2,
        y: rect.midY - measured.height / 2
    )
    NSString(string: string).draw(at: origin, withAttributes: attributes)
}

func roundedRect(_ rect: CGRect, radius: CGFloat, fill color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func drawDesktopBackground(_ bounds: CGRect) {
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.18, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.20, blue: 0.21, alpha: 1),
        NSColor(calibratedRed: 0.19, green: 0.20, blue: 0.16, alpha: 1)
    ])
    gradient?.draw(in: bounds, angle: 35)
}

func drawDemoWindow(_ rect: CGRect) {
    roundedRect(rect, radius: 18, fill: NSColor(calibratedWhite: 0.96, alpha: 1))
    roundedRect(CGRect(x: rect.minX, y: rect.maxY - 62, width: rect.width, height: 62), radius: 18, fill: NSColor(calibratedWhite: 0.90, alpha: 1))
    fill(CGRect(x: rect.minX, y: rect.maxY - 80, width: rect.width, height: 22), NSColor(calibratedWhite: 0.90, alpha: 1))

    for index in 0..<3 {
        let color: NSColor = [NSColor.systemRed, NSColor.systemYellow, NSColor.systemGreen][index]
        roundedRect(CGRect(x: rect.minX + 28 + CGFloat(index * 28), y: rect.maxY - 40, width: 13, height: 13), radius: 6.5, fill: color)
    }

    text("Quarterly roadmap", at: CGPoint(x: rect.minX + 44, y: rect.maxY - 128), size: 38, weight: .bold, color: NSColor(calibratedWhite: 0.12, alpha: 1))
    text("Presenter view", at: CGPoint(x: rect.minX + 48, y: rect.maxY - 168), size: 20, weight: .medium, color: NSColor(calibratedWhite: 0.35, alpha: 1))

    let cardWidth = (rect.width - 128) / 3
    for index in 0..<3 {
        let x = rect.minX + 44 + CGFloat(index) * (cardWidth + 20)
        let card = CGRect(x: x, y: rect.minY + 110, width: cardWidth, height: 455)
        roundedRect(card, radius: 12, fill: NSColor.white)
        text(["Now", "Next", "Later"][index], at: CGPoint(x: card.minX + 28, y: card.maxY - 64), size: 28, weight: .bold, color: NSColor(calibratedWhite: 0.12, alpha: 1))

        for row in 0..<5 {
            let y = card.maxY - 124 - CGFloat(row * 58)
            roundedRect(CGRect(x: card.minX + 28, y: y, width: card.width - 56, height: 16), radius: 8, fill: NSColor(calibratedWhite: 0.82, alpha: 1))
            roundedRect(CGRect(x: card.minX + 28, y: y - 26, width: card.width - CGFloat(98 + row * 18), height: 12), radius: 6, fill: NSColor(calibratedWhite: 0.90, alpha: 1))
        }
    }
}

func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor, width: CGFloat) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    stroke(path, color: color, width: width)

    let angle = atan2(end.y - start.y, end.x - start.x)
    let headLength = max(width * 3, 24)
    let headAngle = CGFloat.pi / 7
    let left = CGPoint(x: end.x - headLength * cos(angle - headAngle), y: end.y - headLength * sin(angle - headAngle))
    let right = CGPoint(x: end.x - headLength * cos(angle + headAngle), y: end.y - headLength * sin(angle + headAngle))

    let head = NSBezierPath()
    head.move(to: left)
    head.line(to: end)
    head.line(to: right)
    stroke(head, color: color, width: width)
}

try canvas.render("drawing-tools.png") { bounds in
    drawDesktopBackground(bounds)
    let window = CGRect(x: 120, y: 96, width: 1160, height: 680)
    drawDemoWindow(window)

    roundedRect(
        CGRect(x: 172, y: 625, width: 410, height: 44),
        radius: 10,
        fill: NSColor.systemYellow.withAlphaComponent(0.56)
    )

    drawArrow(
        from: CGPoint(x: 1130, y: 275),
        to: CGPoint(x: 910, y: 420),
        color: NSColor.systemRed.withAlphaComponent(0.94),
        width: 11
    )

    let freehand = NSBezierPath()
    freehand.move(to: CGPoint(x: 220, y: 225))
    freehand.curve(to: CGPoint(x: 520, y: 254), controlPoint1: CGPoint(x: 310, y: 315), controlPoint2: CGPoint(x: 420, y: 170))
    freehand.curve(to: CGPoint(x: 755, y: 218), controlPoint1: CGPoint(x: 610, y: 340), controlPoint2: CGPoint(x: 680, y: 120))
    stroke(freehand, color: NSColor.systemBlue.withAlphaComponent(0.95), width: 10)

    text("Ship this first", at: CGPoint(x: 760, y: 555), size: 42, weight: .bold, color: NSColor.systemRed)
}

try canvas.render("spotlight.png") { bounds in
    drawDesktopBackground(bounds)
    let window = CGRect(x: 120, y: 96, width: 1160, height: 680)
    drawDemoWindow(window)

    NSColor.black.withAlphaComponent(0.70).setFill()
    bounds.fill()

    let focus = CGRect(x: 670, y: 305, width: 350, height: 250)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(ovalIn: focus).addClip()
    drawDemoWindow(window)
    NSGraphicsContext.restoreGraphicsState()

    stroke(NSBezierPath(ovalIn: focus), color: NSColor.white.withAlphaComponent(0.28), width: 5)
}

try canvas.render("break.png") { bounds in
    fill(bounds, NSColor.black)
    text("Break", at: CGPoint(x: 585, y: 535), size: 54, weight: .semibold, color: NSColor(calibratedWhite: 0.78, alpha: 1))
    centeredText("04:59", in: CGRect(x: 0, y: 255, width: bounds.width, height: 230), size: 164, weight: .bold, color: .white)
}

print("Generated README screenshots in \(outputDirectory.path)")
