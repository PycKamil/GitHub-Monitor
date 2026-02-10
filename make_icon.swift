import AppKit

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let sourceURL = URL(fileURLWithPath: "\(scriptDir)/AppIcon.png")
let outputDir = "\(scriptDir)/Assets.xcassets/AppIcon.appiconset"

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fatalError("Cannot load \(sourceURL.path)")
}

let sizes: [(filename: String, pixels: Int)] = [
    ("AppIcon-16.png", 16),
    ("AppIcon-32.png", 32),
    ("AppIcon-32@2x.png", 32),
    ("AppIcon-64@2x.png", 64),
    ("AppIcon-128.png", 128),
    ("AppIcon-256.png", 256),
    ("AppIcon-256@2x.png", 256),
    ("AppIcon-512.png", 512),
    ("AppIcon-512@2x.png", 512),
    ("AppIcon-1024.png", 1024),
]

for entry in sizes {
    let s = entry.pixels
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: s, pixelsHigh: s,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    sourceImage.draw(in: NSRect(x: 0, y: 0, width: s, height: s))
    NSGraphicsContext.restoreGraphicsState()

    let pngData = rep.representation(using: .png, properties: [:])!
    let outURL = URL(fileURLWithPath: "\(outputDir)/\(entry.filename)")
    try pngData.write(to: outURL)
    print("Wrote \(entry.filename) (\(s)x\(s))")
}
