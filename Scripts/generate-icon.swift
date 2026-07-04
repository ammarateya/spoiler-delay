#!/usr/bin/env swift
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: output)
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func render(points: Int, scale: Int, name: String) throws {
    let pixels = points * scale
    let factor = CGFloat(pixels) / 1024
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: factor, y: factor)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let background = NSBezierPath(roundedRect: NSRect(x: 34, y: 34, width: 956, height: 956), xRadius: 224, yRadius: 224)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.27, green: 0.64, blue: 1, alpha: 1),
        NSColor(calibratedRed: 0.11, green: 0.33, blue: 0.81, alpha: 1)
    ])!.draw(in: background, angle: -48)

    let ball = NSBezierPath(ovalIn: NSRect(x: 218, y: 218, width: 588, height: 588))
    NSColor.white.withAlphaComponent(0.055).setFill()
    ball.fill()
    NSColor.white.setStroke()
    ball.lineWidth = 58
    ball.stroke()

    func stroke(_ points: [NSPoint], width: CGFloat, alpha: CGFloat = 1, closed: Bool = false) {
        guard let first = points.first else { return }
        let path = NSBezierPath()
        path.move(to: first)
        for point in points.dropFirst() { path.line(to: point) }
        if closed { path.close() }
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        NSColor.white.withAlphaComponent(alpha).setStroke()
        path.stroke()
    }

    stroke([.init(x: 512, y: 396), .init(x: 425, y: 345), .init(x: 337, y: 409), .init(x: 371, y: 514), .init(x: 468, y: 528), .init(x: 512, y: 490)], width: 38, closed: true)
    stroke([.init(x: 425, y: 345), .init(x: 390, y: 229)], width: 34)
    stroke([.init(x: 337, y: 409), .init(x: 238, y: 377)], width: 34)
    stroke([.init(x: 371, y: 514), .init(x: 284, y: 624)], width: 34)
    stroke([.init(x: 468, y: 528), .init(x: 427, y: 775)], width: 34)
    stroke([.init(x: 512, y: 218), .init(x: 512, y: 806)], width: 22, alpha: 0.22)

    stroke([.init(x: 512, y: 512), .init(x: 512, y: 340)], width: 46)
    stroke([.init(x: 512, y: 512), .init(x: 666, y: 601)], width: 46)
    for tick in [
        [NSPoint(x: 657, y: 261), NSPoint(x: 642, y: 290)],
        [NSPoint(x: 747, y: 351), NSPoint(x: 718, y: 368)],
        [NSPoint(x: 780, y: 512), NSPoint(x: 746, y: 512)],
        [NSPoint(x: 747, y: 673), NSPoint(x: 718, y: 656)],
        [NSPoint(x: 657, y: 763), NSPoint(x: 642, y: 734)]
    ] { stroke(tick, width: 28) }
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 487, y: 487, width: 50, height: 50)).fill()

    context.flushGraphics()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
    try png.write(to: URL(fileURLWithPath: output).appendingPathComponent(name))
}

for points in [16, 32, 128, 256, 512] {
    try render(points: points, scale: 1, name: "icon_\(points)x\(points).png")
    try render(points: points, scale: 2, name: "icon_\(points)x\(points)@2x.png")
}
