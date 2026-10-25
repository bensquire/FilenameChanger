import CoreGraphics
import Foundation
import PDFKit
import UniformTypeIdentifiers
import Vision

/// Reads the text a document shows, for Smart Name to summarise: a PDF's own
/// text layer, OCR for a scan or a photo, or a plain-text file as-is. Only the
/// start is kept — the title and date sit near the top, and the model's
/// context is small.
public enum DocumentText {
    public enum Failure: Error, Equatable, LocalizedError {
        case unsupported
        case unreadable
        case noText

        public var errorDescription: String? {
            switch self {
            case .unsupported: return "Smart Name reads PDFs, images and text files."
            case .unreadable: return "The file couldn’t be opened."
            case .noText: return "No text was found in the file."
            }
        }
    }

    /// About 1,500–2,000 tokens of English: room in the on-device model's
    /// 4,096-token context for the instructions, schema and answer.
    /// /documentation/foundationmodels/managing-the-context-window
    static let characterLimit = 6_000

    /// A text layer shorter than this is a scan's stray marks, not its words.
    static let scanThreshold = 40

    @concurrent
    public static func extract(from url: URL) async throws -> String {
        let type =
            (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: url.pathExtension)
        guard let type else { throw Failure.unsupported }
        let text: String
        if type.conforms(to: .pdf) {
            text = try await pdfText(url)
        } else if type.conforms(to: .image) {
            text = try await recognizeText(in: RecognizeTextRequest().perform(on: url))
        } else if type.conforms(to: .plainText) {
            text = try startOfTextFile(url)
        } else {
            throw Failure.unsupported
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.noText }
        return String(trimmed.prefix(characterLimit))
    }

    /// The first part of a text file, without loading the rest: a huge log
    /// or CSV is named from its start like anything else. Generous over the
    /// character limit, since UTF-8 may take several bytes a character.
    private static func startOfTextFile(_ url: URL) throws -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw Failure.unreadable }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: characterLimit * 4)) ?? Data()
        // A cut can split a character; decoding lossily keeps the rest.
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - PDF

    private static func pdfText(_ url: URL) async throws -> String {
        guard let document = PDFDocument(url: url) else { throw Failure.unreadable }
        let pages = (0..<min(document.pageCount, 3)).compactMap { document.page(at: $0) }
        let layer = pages.compactMap(\.string).joined(separator: "\n")
        if layer.trimmingCharacters(in: .whitespacesAndNewlines).count >= scanThreshold {
            return layer
        }
        // A scan: the pages are pictures of text, so read them as pictures.
        var recognized: [String] = []
        for page in pages.prefix(2) {
            guard let image = render(page) else { continue }
            recognized.append(try await recognizeText(in: RecognizeTextRequest().perform(on: image)))
        }
        return recognized.joined(separator: "\n")
    }

    /// Draw a page at twice its point size — enough detail for OCR on a
    /// typical scan — but never past `maxPixels` on its longer side, so a
    /// poster-sized page can't make a gigabyte bitmap.
    private static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let maxPixels: CGFloat = 4_000
        let scale = min(2, maxPixels / max(bounds.width, bounds.height, 1))
        guard
            let context = CGContext(
                data: nil, width: Int(bounds.width * scale), height: Int(bounds.height * scale),
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.setFillColor(.white)
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(context.width), height: CGFloat(context.height)))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    // MARK: - OCR

    /// The lines Vision read, top to bottom, as they appear on the page.
    /// /documentation/vision/recognizetextrequest
    private static func recognizeText(in observations: [RecognizedTextObservation]) -> String {
        observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
