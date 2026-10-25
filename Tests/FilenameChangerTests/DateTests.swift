import Foundation
import Testing

@testable import RenameKit

@Suite("Date renaming: source, format, placement")
struct DateTests {
    private let hidden = RenameOptions(hideExtension: true)

    /// Noon on 2024-01-15 in the local time zone. DateStamp formats in the
    /// local zone, so the stamp reads the 15th on every machine — from UTC+14
    /// to UTC−12, where a fixed UTC instant would land on the 14th or 16th.
    private var fixedDate: Date {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        components.hour = 12
        components.timeZone = .autoupdatingCurrent
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    @Test("a custom date prepends in the chosen preset format")
    func customDatePrepend() {
        let config = DateConfig(
            source: .custom(fixedDate), format: .preset(.isoDash), placement: .prepend)
        let result = proposedName("report.pdf", .date(config), options: hidden)
        #expect(result == "2024-01-15report.pdf")
    }

    @Test(
        "each preset renders the fixed date as documented",
        arguments: [
            (DatePreset.isoDash, "2024-01-15"),
            (DatePreset.usSlash, "01-15-2024"),
            (DatePreset.euDash, "15-01-2024"),
            (DatePreset.compact, "20240115"),
            (DatePreset.underscored, "2024_01_15"),
            (DatePreset.longText, "Jan 15, 2024"),
        ])
    func presets(preset: DatePreset, expected: String) {
        let config = DateConfig(
            source: .custom(fixedDate), format: .preset(preset), placement: .replaceAll)
        let result = proposedName("x.pdf", .date(config), options: hidden)
        #expect(result == expected + ".pdf")
    }

    @Test("a custom pattern is honoured")
    func customPattern() {
        let config = DateConfig(
            source: .custom(fixedDate), format: .custom("yyyy.MM"), placement: .replaceAll)
        let result = proposedName("x.pdf", .date(config), options: hidden)
        #expect(result == "2024.01.pdf")
    }

    @Test("the EXIF source uses the photo's capture date")
    func exifSource() {
        let provider = FakeMetadataProvider(metadataByName: [
            "photo.jpg": FileMetadata(exifDate: fixedDate)
        ])
        let config = DateConfig(source: .exif, format: .preset(.compact), placement: .prepend)
        let plan = RenameEngine.plan(
            items: items(["photo.jpg"]), function: .date(config), options: hidden,
            provider: provider)
        #expect(plan.first?.proposedName == "20240115photo.jpg")
    }

    @Test("a file with no EXIF date is skipped")
    func exifMissingSkips() {
        let config = DateConfig(source: .exif, format: .preset(.compact), placement: .prepend)
        let result = proposedName("photo.jpg", .date(config), options: hidden)
        #expect(result == nil)
    }
}
