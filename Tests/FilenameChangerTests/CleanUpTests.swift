import Testing

@testable import RenameKit

@Suite("Clean Up: spaces, whitespace, accents, unsafe characters")
struct CleanUpTests {
    @Test("replaces spaces with the chosen character")
    func replacesSpaces() {
        let result = proposedName(
            "my holiday photo.jpg",
            .cleanUp(CleanUpConfig(replaceSpaces: true, spaceReplacement: "_", removeIllegal: false)))
        #expect(result == "my_holiday_photo.jpg")
    }

    @Test("collapses runs of whitespace before replacing")
    func collapsesWhitespace() {
        let result = proposedName(
            "too   many    spaces.txt",
            .cleanUp(
                CleanUpConfig(
                    collapseWhitespace: true, replaceSpaces: true, spaceReplacement: "-",
                    removeIllegal: false)))
        #expect(result == "too-many-spaces.txt")
    }

    @Test("removes accents when asked")
    func removesDiacritics() {
        let result = proposedName(
            "résumé café.pdf",
            .cleanUp(
                CleanUpConfig(
                    replaceSpaces: true, spaceReplacement: "_", removeDiacritics: true,
                    removeIllegal: false)))
        #expect(result == "resume_cafe.pdf")
    }

    @Test("strips characters that are unsafe in a file name")
    func removesIllegal() {
        // "/" can't appear in a real file name, so exercise the other unsafe set.
        let result = proposedName(
            "a*b?c<d>.txt",
            .cleanUp(CleanUpConfig(replaceSpaces: false, removeIllegal: true)))
        #expect(result == "abcd.txt")
    }

    @Test("a name that is already clean is left unchanged")
    func noChangeSkips() {
        let result = proposedName("already_clean.txt", .cleanUp(CleanUpConfig()))
        #expect(result == nil)
    }

    @Test("a base of only unsafe characters is flagged invalid, not made a dotfile")
    func allIllegalBaseIsInvalid() {
        // With Hide Extensions on the base is "???", which cleans to empty;
        // rejoining the extension would make a hidden ".jpg", so it's flagged.
        let plan = RenameEngine.plan(
            items: items(["???.jpg"]),
            function: .cleanUp(CleanUpConfig(replaceSpaces: false, removeIllegal: true)),
            options: RenameOptions(hideExtension: true), provider: FakeMetadataProvider())
        #expect(plan.first?.issue == .invalidName)
    }
}
