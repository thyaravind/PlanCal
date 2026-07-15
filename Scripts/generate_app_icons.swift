import AppKit
import CoreGraphics
import Foundation

private enum IconVariant {
    case standard
    case dark
    case tinted
}

private struct Palette {
    let backgroundStart: CGColor
    let backgroundEnd: CGColor
    let glow: CGColor
    let selectedStart: CGColor
    let selectedEnd: CGColor
    let selectedInk: CGColor
}

private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

private func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: colorSpace,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255,
            CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255,
            alpha
        ]
    )!
}

private func palette(for variant: IconVariant) -> Palette {
    switch variant {
    case .standard:
        Palette(
            backgroundStart: color(0x087CF4),
            backgroundEnd: color(0x5145E7),
            glow: color(0x79DDFF, alpha: 0.72),
            selectedStart: color(0xFFFFFF, alpha: 0.98),
            selectedEnd: color(0xDDEFFF, alpha: 0.96),
            selectedInk: color(0x0878E9)
        )
    case .dark:
        Palette(
            backgroundStart: color(0x052A52),
            backgroundEnd: color(0x17153D),
            glow: color(0x159DFF, alpha: 0.7),
            selectedStart: color(0x5FCBFF),
            selectedEnd: color(0x137CEF),
            selectedInk: color(0xFFFFFF)
        )
    case .tinted:
        Palette(
            backgroundStart: color(0x202020),
            backgroundEnd: color(0x050505),
            glow: color(0xFFFFFF, alpha: 0.34),
            selectedStart: color(0xFFFFFF),
            selectedEnd: color(0xC8C8C8),
            selectedInk: color(0x242424)
        )
    }
}

private func roundedPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

private func fill(_ context: CGContext, path: CGPath, color: CGColor) {
    context.addPath(path)
    context.setFillColor(color)
    context.fillPath()
}

private func stroke(_ context: CGContext, path: CGPath, color: CGColor, width: CGFloat) {
    context.addPath(path)
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.strokePath()
}

private func gradient(
    _ context: CGContext,
    colors: [CGColor],
    start: CGPoint,
    end: CGPoint,
    clippedTo path: CGPath? = nil
) {
    context.saveGState()
    if let path {
        context.addPath(path)
        context.clip()
    }
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
}

private func drawPeriodPill(
    _ context: CGContext,
    rect: CGRect,
    selected: Bool,
    palette: Palette
) {
    let path = roundedPath(rect, radius: rect.width * 0.42)
    if selected {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -18), blur: 34, color: color(0x001A43, alpha: 0.28))
        gradient(
            context,
            colors: [palette.selectedStart, palette.selectedEnd],
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.minY),
            clippedTo: path
        )
        context.restoreGState()
        stroke(context, path: path, color: color(0xFFFFFF, alpha: 0.45), width: 5)
    } else {
        fill(context, path: path, color: color(0xFFFFFF, alpha: 0.13))
        stroke(context, path: path, color: color(0xFFFFFF, alpha: 0.2), width: 3)
    }

    let ink = selected ? palette.selectedInk : color(0xFFFFFF, alpha: 0.86)
    fill(
        context,
        path: roundedPath(
            CGRect(x: rect.midX - rect.width * 0.2, y: rect.maxY - rect.height * 0.28, width: rect.width * 0.4, height: rect.width * 0.075),
            radius: rect.width * 0.04
        ),
        color: ink
    )
    fill(
        context,
        path: CGPath(
            ellipseIn: CGRect(
                x: rect.midX - rect.width * 0.09,
                y: rect.minY + rect.height * 0.2,
                width: rect.width * 0.18,
                height: rect.width * 0.18
            ),
            transform: nil
        ),
        color: ink
    )
}

private func render(size: Int, variant: IconVariant, to url: URL) throws {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    context.interpolationQuality = .high
    let unit = CGFloat(size) / 1024
    context.scaleBy(x: unit, y: unit)
    let palette = palette(for: variant)

    gradient(
        context,
        colors: [palette.backgroundStart, palette.backgroundEnd],
        start: CGPoint(x: 80, y: 980),
        end: CGPoint(x: 940, y: 40)
    )

    let radial = CGGradient(
        colorsSpace: colorSpace,
        colors: [palette.glow, color(0xFFFFFF, alpha: 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        radial,
        startCenter: CGPoint(x: 270, y: 830),
        startRadius: 0,
        endCenter: CGPoint(x: 270, y: 830),
        endRadius: 520,
        options: [.drawsAfterEndLocation]
    )

    let sheet = roundedPath(CGRect(x: 154, y: 145, width: 716, height: 734), radius: 172)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -28), blur: 70, color: color(0x00152E, alpha: 0.28))
    fill(context, path: sheet, color: color(0xFFFFFF, alpha: variant == .tinted ? 0.12 : 0.16))
    context.restoreGState()
    stroke(context, path: sheet, color: color(0xFFFFFF, alpha: 0.34), width: 6)

    fill(context, path: roundedPath(CGRect(x: 292, y: 804, width: 140, height: 32), radius: 16), color: color(0xFFFFFF, alpha: 0.82))
    fill(context, path: roundedPath(CGRect(x: 592, y: 804, width: 140, height: 32), radius: 16), color: color(0xFFFFFF, alpha: 0.82))
    fill(context, path: roundedPath(CGRect(x: 224, y: 744, width: 576, height: 5), radius: 2.5), color: color(0xFFFFFF, alpha: 0.24))

    drawPeriodPill(context, rect: CGRect(x: 222, y: 425, width: 156, height: 236), selected: false, palette: palette)
    drawPeriodPill(context, rect: CGRect(x: 407, y: 378, width: 210, height: 330), selected: true, palette: palette)
    drawPeriodPill(context, rect: CGRect(x: 646, y: 425, width: 156, height: 236), selected: false, palette: palette)

    fill(context, path: roundedPath(CGRect(x: 250, y: 302, width: 524, height: 22), radius: 11), color: color(0xFFFFFF, alpha: 0.8))
    fill(context, path: roundedPath(CGRect(x: 250, y: 250, width: 386, height: 18), radius: 9), color: color(0xFFFFFF, alpha: 0.42))
    fill(context, path: roundedPath(CGRect(x: 250, y: 204, width: 462, height: 18), radius: 9), color: color(0xFFFFFF, alpha: 0.28))

    guard let image = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
    let representation = NSBitmapImageRep(cgImage: image)
    guard let data = representation.representation(using: .png, properties: [.compressionFactor: 1]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url, options: .atomic)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Plancal/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

try render(size: 1024, variant: .standard, to: outputDirectory.appendingPathComponent("AppIcon.png"))
try render(size: 1024, variant: .dark, to: outputDirectory.appendingPathComponent("AppIcon-dark.png"))
try render(size: 1024, variant: .tinted, to: outputDirectory.appendingPathComponent("AppIcon-tinted.png"))

let macSizes: [(name: String, pixels: Int)] = [
    ("AppIcon-mac-16.png", 16),
    ("AppIcon-mac-16@2x.png", 32),
    ("AppIcon-mac-32.png", 32),
    ("AppIcon-mac-32@2x.png", 64),
    ("AppIcon-mac-128.png", 128),
    ("AppIcon-mac-128@2x.png", 256),
    ("AppIcon-mac-256.png", 256),
    ("AppIcon-mac-256@2x.png", 512),
    ("AppIcon-mac-512.png", 512),
    ("AppIcon-mac-512@2x.png", 1024)
]
for asset in macSizes {
    try render(size: asset.pixels, variant: .standard, to: outputDirectory.appendingPathComponent(asset.name))
}
