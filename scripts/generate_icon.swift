#!/usr/bin/env swift
//
//  generate_icon.swift
//  dockPeek
//
//  使用 CoreGraphics 程式化生成 dockPeek App Icon，
//  輸出所有 macOS 所需尺寸的 PNG 到 AppIcon.appiconset/。
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Configuration

let canvasSize: CGFloat = 1024
let outputDir: String = {
    let scriptPath = URL(fileURLWithPath: #file)
    let projectRoot = scriptPath.deletingLastPathComponent().deletingLastPathComponent()
    return projectRoot
        .appendingPathComponent("dockPeek/Assets.xcassets/AppIcon.appiconset")
        .path
}()

// macOS icon sizes: (point size, scale) → pixel size
let iconSizes: [(size: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

// Colors
func rgb(_ hex: UInt32, alpha: CGFloat = 1.0) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return (r, g, b, alpha)
}

let bgTop = rgb(0x1F1F38)
let bgBottom = rgb(0x292B47)
let accentStart = rgb(0xFF9940)
let accentEnd = rgb(0xF25966)

// MARK: - Drawing Helpers

func createColorSpace() -> CGColorSpace {
    CGColorSpace(name: CGColorSpace.sRGB)!
}

func makeColor(_ c: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)) -> CGColor {
    CGColor(colorSpace: createColorSpace(), components: [c.r, c.g, c.b, c.a])!
}

/// Draw a continuous squircle (superellipse) path approximating macOS Big Sur icon shape.
func drawSquircle(in ctx: CGContext, rect: CGRect) {
    let cornerRadius = rect.width * 0.225
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )
    ctx.addPath(path)
}

/// Draw the background gradient fill inside squircle clip.
func drawBackground(in ctx: CGContext) {
    let rect = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)

    ctx.saveGState()
    drawSquircle(in: ctx, rect: rect)
    ctx.clip()

    // Linear gradient top to bottom
    let colorSpace = createColorSpace()
    let colors = [makeColor(bgTop), makeColor(bgBottom)] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)!

    // CoreGraphics origin is bottom-left, so "top" = high y
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: canvasSize / 2, y: canvasSize),
        end: CGPoint(x: canvasSize / 2, y: 0),
        options: []
    )

    ctx.restoreGState()
}

/// Draw subtle amber glow in the center area.
func drawGlow(in ctx: CGContext) {
    ctx.saveGState()

    // Clip to squircle
    let rect = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
    drawSquircle(in: ctx, rect: rect)
    ctx.clip()

    let colorSpace = createColorSpace()
    let glowColor = rgb(0xFF9940, alpha: 0.07)
    let clearColor = rgb(0xFF9940, alpha: 0.0)
    let colors = [makeColor(glowColor), makeColor(clearColor)] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)!

    // Center of glow — CG coords: (512, 604) since CG y is flipped from design coords
    // Design (512, 420) → CG y = 1024 - 420 = 604
    let center = CGPoint(x: 512, y: 604)
    ctx.drawRadialGradient(
        gradient,
        startCenter: center, startRadius: 0,
        endCenter: center, endRadius: 480,
        options: []
    )

    ctx.restoreGState()
}

/// Draw a single window card.
func drawWindowCard(
    in ctx: CGContext,
    centerX: CGFloat,
    centerY: CGFloat,
    rotation: CGFloat,
    scale: CGFloat
) {
    let cardWidth: CGFloat = 380 * scale
    let cardHeight: CGFloat = 275 * scale
    let titleBarHeight: CGFloat = 38 * scale
    let cornerRadius: CGFloat = 16 * scale
    let buttonRadius: CGFloat = 6.5 * scale
    let buttonSpacing: CGFloat = 18 * scale
    let buttonLeftPad: CGFloat = 16 * scale

    // Convert design Y to CG Y
    let cgCenterY = canvasSize - centerY

    ctx.saveGState()
    ctx.translateBy(x: centerX, y: cgCenterY)
    ctx.rotate(by: rotation * .pi / 180.0)
    ctx.translateBy(x: -cardWidth / 2, y: -cardHeight / 2)

    // Shadow
    ctx.setShadow(
        offset: CGSize(width: 0, height: -8 * scale),
        blur: 24 * scale,
        color: CGColor(gray: 0, alpha: 0.3)
    )

    // Card body (white, rounded rect)
    let cardRect = CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.setFillColor(CGColor(colorSpace: createColorSpace(), components: [1, 1, 1, 0.92])!)
    ctx.addPath(cardPath)
    ctx.fillPath()

    // Remove shadow for subsequent drawing
    ctx.setShadow(offset: .zero, blur: 0)

    // Title bar gradient (top of the card = high y in CG)
    ctx.saveGState()
    let titleRect = CGRect(x: 0, y: cardHeight - titleBarHeight, width: cardWidth, height: titleBarHeight)

    // Clip to top rounded corners only
    let titlePath = CGMutablePath()
    titlePath.move(to: CGPoint(x: 0, y: titleRect.minY))
    titlePath.addLine(to: CGPoint(x: 0, y: titleRect.maxY - cornerRadius))
    titlePath.addQuadCurve(
        to: CGPoint(x: cornerRadius, y: titleRect.maxY),
        control: CGPoint(x: 0, y: titleRect.maxY)
    )
    titlePath.addLine(to: CGPoint(x: cardWidth - cornerRadius, y: titleRect.maxY))
    titlePath.addQuadCurve(
        to: CGPoint(x: cardWidth, y: titleRect.maxY - cornerRadius),
        control: CGPoint(x: cardWidth, y: titleRect.maxY)
    )
    titlePath.addLine(to: CGPoint(x: cardWidth, y: titleRect.minY))
    titlePath.closeSubpath()
    ctx.addPath(titlePath)
    ctx.clip()

    let colorSpace = createColorSpace()
    let titleColors = [makeColor(accentStart), makeColor(accentEnd)] as CFArray
    let titleLocations: [CGFloat] = [0.0, 1.0]
    let titleGradient = CGGradient(colorsSpace: colorSpace, colors: titleColors, locations: titleLocations)!
    ctx.drawLinearGradient(
        titleGradient,
        start: CGPoint(x: 0, y: titleRect.midY),
        end: CGPoint(x: cardWidth, y: titleRect.midY),
        options: []
    )
    ctx.restoreGState()

    // Traffic light buttons (in title bar)
    let buttonColors: [(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)] = [
        rgb(0xFF5F57), // red
        rgb(0xFFBD2E), // yellow
        rgb(0x28CA41), // green
    ]
    let buttonY = cardHeight - titleBarHeight / 2

    for (i, color) in buttonColors.enumerated() {
        let bx = buttonLeftPad + buttonRadius + CGFloat(i) * buttonSpacing
        ctx.setFillColor(makeColor(color))
        ctx.fillEllipse(in: CGRect(
            x: bx - buttonRadius,
            y: buttonY - buttonRadius,
            width: buttonRadius * 2,
            height: buttonRadius * 2
        ))
    }

    // Content placeholder lines
    let lineColor = CGColor(colorSpace: createColorSpace(), components: [0.7, 0.7, 0.75, 0.5])!
    ctx.setFillColor(lineColor)
    let lineHeight: CGFloat = 8 * scale
    let lineSpacing: CGFloat = 18 * scale
    let lineLeftPad: CGFloat = 22 * scale
    let contentTop = cardHeight - titleBarHeight - 26 * scale

    let lineWidths: [CGFloat] = [0.75, 0.60, 0.45]
    for (i, widthRatio) in lineWidths.enumerated() {
        let ly = contentTop - CGFloat(i) * lineSpacing
        let lw = (cardWidth - lineLeftPad * 2) * widthRatio
        ctx.fill(CGRect(x: lineLeftPad, y: ly - lineHeight, width: lw, height: lineHeight))
    }

    ctx.restoreGState()
}

/// Draw the Dock bar at the bottom.
func drawDock(in ctx: CGContext) {
    ctx.saveGState()

    // Clip to squircle
    let fullRect = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
    drawSquircle(in: ctx, rect: fullRect)
    ctx.clip()

    // Dock pill shape
    let dockWidth: CGFloat = 560
    let dockHeight: CGFloat = 64
    let dockX = (canvasSize - dockWidth) / 2
    // Design Y ~850 (near bottom) → CG y = 1024 - 850 = 174; bottom edge
    let dockY: CGFloat = 100
    let dockRect = CGRect(x: dockX, y: dockY, width: dockWidth, height: dockHeight)
    let dockCorner = dockHeight / 2

    let dockPath = CGPath(
        roundedRect: dockRect,
        cornerWidth: dockCorner,
        cornerHeight: dockCorner,
        transform: nil
    )

    // Semi-transparent white
    ctx.setFillColor(CGColor(colorSpace: createColorSpace(), components: [1, 1, 1, 0.12])!)
    ctx.addPath(dockPath)
    ctx.fillPath()

    // Dock dots
    let dotRadius: CGFloat = 12
    let dotSpacing: CGFloat = 75
    let dotsStartX = canvasSize / 2 - dotSpacing * 1.5
    let dotCenterY = dockY + dockHeight / 2

    for i in 0..<4 {
        let dx = dotsStartX + CGFloat(i) * dotSpacing

        if i == 1 {
            // Highlighted dot with accent gradient
            ctx.saveGState()
            let dotRect = CGRect(
                x: dx - dotRadius, y: dotCenterY - dotRadius,
                width: dotRadius * 2, height: dotRadius * 2
            )
            ctx.addEllipse(in: dotRect)
            ctx.clip()

            let colorSpace = createColorSpace()
            let dotColors = [makeColor(accentStart), makeColor(accentEnd)] as CFArray
            let dotLocations: [CGFloat] = [0.0, 1.0]
            let dotGradient = CGGradient(colorsSpace: colorSpace, colors: dotColors, locations: dotLocations)!
            ctx.drawLinearGradient(
                dotGradient,
                start: CGPoint(x: dotRect.minX, y: dotRect.midY),
                end: CGPoint(x: dotRect.maxX, y: dotRect.midY),
                options: []
            )
            ctx.restoreGState()
        } else {
            // Normal dot
            ctx.setFillColor(CGColor(colorSpace: createColorSpace(), components: [1, 1, 1, 0.25])!)
            ctx.fillEllipse(in: CGRect(
                x: dx - dotRadius, y: dotCenterY - dotRadius,
                width: dotRadius * 2, height: dotRadius * 2
            ))
        }
    }

    ctx.restoreGState()
}

// MARK: - Main Rendering

func renderMasterIcon() -> CGContext {
    let size = Int(canvasSize)
    let colorSpace = createColorSpace()
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // Enable anti-aliasing
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // 1. Background
    drawBackground(in: ctx)

    // 2. Glow
    drawGlow(in: ctx)

    // 3. Window cards (back to front)
    // Back left
    drawWindowCard(in: ctx, centerX: 280, centerY: 450, rotation: -6, scale: 0.85)
    // Back right
    drawWindowCard(in: ctx, centerX: 744, centerY: 455, rotation: 5, scale: 0.87)
    // Front center
    drawWindowCard(in: ctx, centerX: 512, centerY: 400, rotation: 0, scale: 1.0)

    // 4. Dock bar
    drawDock(in: ctx)

    return ctx
}

func savePNG(image: CGImage, to path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("  ERROR: Cannot create image destination for \(path)")
        return false
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        print("  ERROR: Failed to write PNG to \(path)")
        return false
    }
    return true
}

func resizeImage(_ source: CGImage, to pixelSize: Int) -> CGImage? {
    let colorSpace = createColorSpace()
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.draw(source, in: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    return ctx.makeImage()
}

func generateContentsJSON(entries: [(filename: String, size: Int, scale: Int)]) -> String {
    var images: [String] = []
    for entry in entries {
        images.append("""
            {
              "filename" : "\(entry.filename)",
              "idiom" : "mac",
              "scale" : "\(entry.scale)x",
              "size" : "\(entry.size)x\(entry.size)"
            }
        """)
    }
    return """
    {
      "images" : [
    \(images.joined(separator: ",\n"))
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
}

// MARK: - Entry Point

print("Generating dockPeek App Icon...")
print("Output directory: \(outputDir)")

// Ensure output directory exists
let fm = FileManager.default
if !fm.fileExists(atPath: outputDir) {
    try! fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
}

// Render master 1024x1024
let masterCtx = renderMasterIcon()
guard let masterImage = masterCtx.makeImage() else {
    print("ERROR: Failed to render master icon")
    exit(1)
}

// Export all sizes
var entries: [(filename: String, size: Int, scale: Int)] = []
var allSuccess = true

for (size, scale) in iconSizes {
    let pixelSize = size * scale
    let filename = "icon_\(size)x\(size)@\(scale)x.png"
    let path = "\(outputDir)/\(filename)"

    guard let resized = resizeImage(masterImage, to: pixelSize) else {
        print("  ERROR: Failed to resize to \(pixelSize)x\(pixelSize)")
        allSuccess = false
        continue
    }

    if savePNG(image: resized, to: path) {
        print("  ✓ \(filename) (\(size)x\(size)@\(scale)x → \(pixelSize)px)")
        entries.append((filename: filename, size: size, scale: scale))
    } else {
        allSuccess = false
    }
}

// Write Contents.json
let contentsPath = "\(outputDir)/Contents.json"
let json = generateContentsJSON(entries: entries)
try! json.write(toFile: contentsPath, atomically: true, encoding: .utf8)
print("  ✓ Contents.json updated")

if allSuccess {
    print("\nDone! All \(entries.count) icon sizes generated successfully.")
} else {
    print("\nWARNING: Some icons failed to generate.")
    exit(1)
}
