import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import RenameIntelligence

@Suite("Smart Name: reading a document's text")
struct DocumentTextTests {
    private let sandbox: Sandbox

    init() throws {
        sandbox = try Sandbox()
    }

    private static let letter = "ACME ENERGY LTD\nElectricity Bill\nIssued 3 March 2026"
    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792)

    @Test("a text file is read as it is, cut to the model's budget")
    func plainTextIsTruncated() async throws {
        let url = sandbox.url("long.txt")
        try String(repeating: "a", count: DocumentText.characterLimit + 500)
            .write(to: url, atomically: true, encoding: .utf8)

        let text = try await DocumentText.extract(from: url)

        #expect(text.count == DocumentText.characterLimit)
    }

    @Test("a PDF's own text is read")
    func pdfTextLayer() async throws {
        let url = sandbox.url("bill.pdf")
        try writePDF(to: url) { context in Self.draw(Self.letter, in: context) }

        let text = try await DocumentText.extract(from: url)

        #expect(text.contains("Electricity Bill"))
    }

    @Test("a scanned PDF, a picture of text, is read by OCR")
    func scannedPDF() async throws {
        let url = sandbox.url("scan.pdf")
        let image = try #require(Self.textImage())
        try writePDF(to: url) { context in context.draw(image, in: Self.page) }

        let text = try await DocumentText.extract(from: url)

        #expect(text.contains("Electricity Bill"))
    }

    @Test("a photo of a document is read by OCR")
    func imageOCR() async throws {
        let url = sandbox.url("photo.png")
        let image = try #require(Self.textImage())
        let destination = try #require(
            CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))

        let text = try await DocumentText.extract(from: url)

        #expect(text.contains("Electricity Bill"))
    }

    @Test("a file Smart Name can't read says so")
    func unsupportedType() async throws {
        let url = sandbox.url("archive.zip")
        try Data([0x50, 0x4B, 0x05, 0x06]).write(to: url)

        await #expect(throws: DocumentText.Failure.unsupported) {
            try await DocumentText.extract(from: url)
        }
    }

    // MARK: - Fixtures

    private func writePDF(to url: URL, _ drawPage: (CGContext) -> Void) throws {
        var box = Self.page
        let context = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        drawPage(context)
        context.endPDFPage()
        context.closePDF()
    }

    /// A white page with the letter's text, as a bitmap: what a scanner makes.
    private static func textImage() -> CGImage? {
        guard
            let context = CGContext(
                data: nil, width: Int(page.width), height: Int(page.height), bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.setFillColor(.white)
        context.fill(page)
        draw(letter, in: context)
        return context.makeImage()
    }

    /// Black 24-point text near the top of the page, one line per line.
    private static func draw(_ text: String, in context: CGContext) {
        let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor.black,
        ]
        for (index, line) in text.split(separator: "\n").enumerated() {
            let ctLine = CTLineCreateWithAttributedString(
                NSAttributedString(string: String(line), attributes: attributes))
            context.textPosition = CGPoint(x: 72, y: page.height - 100 - CGFloat(index) * 40)
            CTLineDraw(ctLine, context)
        }
    }
}
