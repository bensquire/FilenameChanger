import Testing

@testable import RenameKit

@Suite("Edit functions: remove, insert, change case")
struct EditFunctionTests {
    @Test("remove in range drops the chosen characters")
    func removeRange() {
        // "IMG_0001" with location 0, length 4 removes "IMG_".
        let result = proposedName(
            "IMG_0001.jpg", .removeCharacters(.range(location: 0, length: 4)),
            options: RenameOptions(hideExtension: true))
        #expect(result == "0001.jpg")
    }

    @Test("a remove range starting past the name skips the row")
    func removeRangeBeyondSkips() {
        let result = proposedName(
            "ab.jpg", .removeCharacters(.range(location: 20, length: 4)),
            options: RenameOptions(hideExtension: true))
        #expect(result == nil)
    }

    @Test("a remove range whose end overshoots clamps to the name")
    func removeRangeClamps() {
        let result = proposedName(
            "photo.jpg", .removeCharacters(.range(location: 3, length: 999)),
            options: RenameOptions(hideExtension: true))
        #expect(result == "pho.jpg")
    }

    @Test("remove from end drops the last characters")
    func removeFromEnd() {
        let result = proposedName(
            "photo123.jpg", .removeCharacters(.fromEnd(count: 3)),
            options: RenameOptions(hideExtension: true))
        #expect(result == "photo.jpg")
    }

    @Test("insert at an index places the text there")
    func insertAtIndex() {
        let result = proposedName(
            "photo.jpg", .insertCharacters(text: "my-", mode: .atIndex(0), padToLength: nil))
        #expect(result == "my-photo.jpg")
    }

    @Test("insert at an index past the name skips the row")
    func insertBeyondSkips() {
        let result = proposedName(
            "ab.jpg", .insertCharacters(text: "x", mode: .atIndex(99), padToLength: nil))
        #expect(result == nil)
    }

    @Test("pad to length repeats the text until the minimum is reached")
    func padToLength() {
        // "7" padded with "0" from the end to length 4 → "7000".
        let result = proposedName(
            "7", .insertCharacters(text: "0", mode: .fromEnd, padToLength: 4))
        #expect(result == "7000")
    }

    @Test(
        "pad to length fills at the insertion point",
        arguments: [
            ("1", "001"),
            ("12", "012"),
        ])
    func padAtIndex(input: String, expected: String) {
        // Zero-padding numbers: "0" inserted at the front, up to 3 characters.
        let result = proposedName(
            input, .insertCharacters(text: "0", mode: .atIndex(0), padToLength: 3))
        #expect(result == expected)
    }

    @Test("a multi-character pad is cut to the exact length")
    func padCutsToLength() {
        // "7" needs 3 more characters: "ab" repeats as "aba".
        let result = proposedName(
            "7", .insertCharacters(text: "ab", mode: .atIndex(0), padToLength: 4))
        #expect(result == "aba7")
    }

    @Test("a name already at the padded length is left alone")
    func padAlreadyLongEnough() {
        let result = proposedName(
            "longname", .insertCharacters(text: "0", mode: .fromEnd, padToLength: 4))
        #expect(result == nil)
    }

    @Test(
        "change case transforms the base, leaving the extension when hidden",
        arguments: [
            (TextCase.title, "My Holiday Photo.jpg"),
            (TextCase.upper, "MY HOLIDAY PHOTO.jpg"),
            (TextCase.lower, "my holiday photo.jpg"),
            (TextCase.snake, "my_holiday_photo.jpg"),
            (TextCase.kebab, "my-holiday-photo.jpg"),
            (TextCase.camel, "myHolidayPhoto.jpg"),
            (TextCase.pascal, "MyHolidayPhoto.jpg"),
            (TextCase.screamingSnake, "MY_HOLIDAY_PHOTO.jpg"),
        ])
    func changeCase(textCase: TextCase, expected: String) {
        let result = proposedName(
            "my holiday PHOTO.jpg", .changeCase(textCase),
            options: RenameOptions(hideExtension: true))
        #expect(result == expected)
    }

    @Test(
        "Title Case keeps acronyms and mixed-case words, and lowers shouting",
        arguments: [
            ("Shopping list", "Shopping List"),
            ("statement of account", "Statement of Account"),
            ("VAT return for the iPhone", "VAT Return for the iPhone"),
            ("my holiday PHOTO", "My Holiday Photo"),
            ("MY HOLIDAY PHOTO", "My Holiday Photo"),
            ("ACME ENERGY LTD", "Acme Energy Ltd"),
            ("BT", "BT"),
            // Shouting is lowered whole, so a short acronym in it goes too.
            ("HSBC UK", "Hsbc Uk"),
            ("my_holiday-photo", "My_Holiday-Photo"),
            ("the end of an era", "The End of an Era"),
            ("don't panic", "Don't Panic"),
        ])
    func titleCase(text: String, expected: String) {
        #expect(TextCase.titleCased(text) == expected)
    }

    @Test(
        "word-splitting cases join across spaces, underscores, hyphens and camelCase",
        arguments: [
            // Mixed separators collapse to the chosen convention.
            (TextCase.snake, "file-name_v2", "file_name_v2"),
            (TextCase.kebab, "file_name v2", "file-name-v2"),
            // camelCase and PascalCase boundaries are detected when splitting.
            (TextCase.snake, "myReportFinal", "my_report_final"),
            (TextCase.kebab, "MyReportFinal", "my-report-final"),
            // An acronym run splits before its trailing word.
            (TextCase.snake, "XMLHttpRequest", "xml_http_request"),
            // Round-trip into camel / pascal.
            (TextCase.camel, "my report final", "myReportFinal"),
            (TextCase.pascal, "my-report-final", "MyReportFinal"),
            (TextCase.screamingSnake, "my report", "MY_REPORT"),
        ])
    func wordCasing(textCase: TextCase, input: String, expected: String) {
        // No extension here, so the whole name is the base.
        let result = proposedName(input, .changeCase(textCase))
        #expect(result == expected)
    }

    @Test("a name with no letters or digits is left unchanged by a word case")
    func wordCasingEmptyIsSkipped() {
        #expect(proposedName("___", .changeCase(.snake)) == nil)
    }

    @Test(
        "word-splitting cases keep the extension even when Hide Extensions is off",
        arguments: [
            (TextCase.snake, "My Photo.JPG", "my_photo.JPG"),
            (TextCase.kebab, "My Photo.JPG", "my-photo.JPG"),
            (TextCase.screamingSnake, "report final.pdf", "REPORT_FINAL.pdf"),
            (TextCase.camel, "my report.txt", "myReport.txt"),
            // A multi-dot name: only the real extension is preserved; inner dots
            // are word separators, and it reads the same with Hide Extensions on.
            (TextCase.snake, "data.backup.json", "data_backup.json"),
        ])
    func wordCasingPreservesExtension(textCase: TextCase, input: String, expected: String) {
        #expect(proposedName(input, .changeCase(textCase)) == expected)
    }

    @Test("Title/lower/upper still case the extension when Hide Extensions is off")
    func simpleCasesStillTouchExtension() {
        #expect(proposedName("Photo.JPG", .changeCase(.lower)) == "photo.jpg")
        #expect(proposedName("photo.jpg", .changeCase(.upper)) == "PHOTO.JPG")
    }
}
