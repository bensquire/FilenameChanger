// Generates the FilenameChanger app icon (same family as PaperDrop/PaperPress:
// flat vivid tile, bold white glyph, soft shadows). The glyph is a filename
// field with a text caret — a name being edited.
// Run: swift icon/makeicon.swift   (from the repo root)
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: "icon/FilenameChanger.iconset", isDirectory: true)
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func draw(_ size: Int) -> CGImage {
    let s = CGFloat(size)
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // Flat tile (indigo — the family's third hue, after blue and vermillion).
    let bg = CGColor(red: 0.30, green: 0.31, blue: 0.86, alpha: 1)
    let tile = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
        cornerWidth: s * 0.225, cornerHeight: s * 0.225, transform: nil)
    ctx.addPath(tile)
    ctx.setFillColor(bg)
    ctx.fillPath()

    func softShadow() {
        ctx.setShadow(
            offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.025,
            color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.28))
    }

    // y measured from the top.
    func rect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat) -> CGPath {
        CGPath(
            roundedRect: CGRect(x: x * s, y: s - (y + h) * s, width: w * s, height: h * s),
            cornerWidth: r * s, cornerHeight: r * s, transform: nil)
    }

    // The name field: a white rounded rectangle.
    softShadow()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.addPath(rect(x: 0.18, y: 0.37, w: 0.64, h: 0.26, r: 0.05))
    ctx.fillPath()

    // Text bars inside the field, and a caret, cut in the tile colour.
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.setFillColor(bg)
    ctx.addPath(rect(x: 0.26, y: 0.475, w: 0.22, h: 0.05, r: 0.025))
    ctx.fillPath()
    // Blinking caret just after the text.
    ctx.addPath(rect(x: 0.50, y: 0.45, w: 0.022, h: 0.10, r: 0.011))
    ctx.fillPath()

    // Rename arrow beneath the field: the name changing.
    softShadow()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: s - y * s) }
    let shaftW = 0.055
    let headW = 0.16
    let leftX = 0.30
    let rightApex = 0.70
    let midY = 0.72
    let headBase = rightApex - headW * 0.62
    let path = CGMutablePath()
    path.move(to: pt(leftX, midY - shaftW / 2))
    path.addLine(to: pt(headBase, midY - shaftW / 2))
    path.addLine(to: pt(headBase, midY - headW / 2))
    path.addLine(to: pt(rightApex, midY))
    path.addLine(to: pt(headBase, midY + headW / 2))
    path.addLine(to: pt(headBase, midY + shaftW / 2))
    path.addLine(to: pt(leftX, midY + shaftW / 2))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.fillPath()

    return ctx.makeImage()!
}

func write(_ image: CGImage, _ name: String) {
    let url = out.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

for base in [16, 32, 128, 256, 512] {
    write(draw(base), "icon_\(base)x\(base).png")
    write(draw(base * 2), "icon_\(base)x\(base)@2x.png")
}
print("iconset written to \(out.path)")
