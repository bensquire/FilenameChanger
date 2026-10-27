// Generates the FilenameChanger app icon (same family as PaperDrop/PaperPress:
// flat vivid tile, bold white glyph, soft shadows). The glyph is a stack of
// filename fields, the front one being edited — many names changed at once.
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

    // Flat orange tile.
    let bg = CGColor(red: 0.918, green: 0.345, blue: 0.047, alpha: 1)
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

    // White mixed into the tile colour: the cards behind are solid tints, not
    // see-through white, so their shadows don't show through them.
    func tint(_ white: CGFloat) -> CGColor {
        let c = bg.components ?? [0, 0, 0, 1]
        return CGColor(
            red: c[0] + (1 - c[0]) * white, green: c[1] + (1 - c[1]) * white,
            blue: c[2] + (1 - c[2]) * white, alpha: 1)
    }

    // The stack, back to front: two names waiting, then the one being edited.
    ctx.setFillColor(tint(0.4))
    ctx.addPath(rect(x: 0.221, y: 0.206, w: 0.558, h: 0.194, r: 0.053))
    ctx.fillPath()
    softShadow()
    ctx.setFillColor(tint(0.7))
    ctx.addPath(rect(x: 0.170, y: 0.369, w: 0.660, h: 0.214, r: 0.058))
    ctx.fillPath()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.addPath(rect(x: 0.121, y: 0.546, w: 0.757, h: 0.243, r: 0.066))
    ctx.fillPath()

    // The selected text in the front field, in the tile colour, and the caret.
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.setFillColor(bg)
    ctx.addPath(rect(x: 0.197, y: 0.638, w: 0.364, h: 0.061, r: 0.030))
    ctx.fillPath()
    ctx.setFillColor(CGColor(red: 0.122, green: 0.161, blue: 0.216, alpha: 1))
    ctx.addPath(rect(x: 0.580, y: 0.614, w: 0.029, h: 0.109, r: 0.015))
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
