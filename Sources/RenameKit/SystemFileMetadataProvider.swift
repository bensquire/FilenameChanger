import Foundation
import ImageIO

/// The production `FileMetadataProvider`: file dates from the file system and
/// the capture date from a photo's EXIF, read through `ImageIO`.
public struct SystemFileMetadataProvider: FileMetadataProvider {
    public init() {}

    public func metadata(for url: URL) -> FileMetadata {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return FileMetadata(
            creationDate: values?.creationDate,
            modificationDate: values?.contentModificationDate,
            exifDate: exifDate(for: url))
    }

    public func fileExists(at url: URL) -> Bool {
        // The shared manager is documented thread-safe for these queries.
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    private func exifDate(for url: URL) -> Date? {
        // Only the properties are read, so ask ImageIO not to cache a decoded
        // image; caching is the default.
        // /documentation/imageio/kcgimagesourceshouldcache
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        else { return nil }
        // EXIF stores capture time as "yyyy:MM:dd HH:mm:ss" in local time.
        let original =
            exif[kCGImagePropertyExifDateTimeOriginal] as? String
            ?? exif[kCGImagePropertyExifDateTimeDigitized] as? String
        guard let original else { return nil }
        return Self.exifFormatter.date(from: original)
    }

    private static let exifFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
}
