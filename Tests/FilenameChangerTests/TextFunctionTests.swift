import Testing

@testable import RenameKit

@Suite("Text functions: prepend, append, replace, wildcard, regex")
struct TextFunctionTests {
    @Test("prepend puts the text before the whole name")
    func prependBeforeName() {
        // Arrange / Act
        let result = proposedName("photo.jpg", .prepend(text: "2024-"))
        // Assert
        #expect(result == "2024-photo.jpg")
    }

    @Test("append without hiding the extension lands after it")
    func appendAfterExtension() {
        let result = proposedName("photo.jpg", .append(text: "-edit"))
        #expect(result == "photo.jpg-edit")
    }

    @Test("append with Hide Extensions lands before the extension")
    func appendBeforeExtensionWhenHidden() {
        let result = proposedName(
            "photo.jpg", .append(text: "-edit"), options: RenameOptions(hideExtension: true))
        #expect(result == "photo-edit.jpg")
    }

    @Test("replace first changes only the first occurrence")
    func replaceFirstOnly() {
        let result = proposedName("a-a-a.txt", .replaceFirst(find: "a", with: "b"))
        #expect(result == "b-a-a.txt")
    }

    @Test("replace last changes only the last occurrence")
    func replaceLastOnly() {
        let result = proposedName("a-a-a.txt", .replaceLast(find: "a", with: "b"))
        #expect(result == "a-a-b.txt")
    }

    @Test("replace all changes every occurrence")
    func replaceAllOccurrences() {
        let result = proposedName("a-a-a.txt", .replaceAll(find: "a", with: "b"))
        #expect(result == "b-b-b.txt")
    }

    @Test("a replace that matches nothing skips the row")
    func replaceNoMatchSkips() {
        let result = proposedName("photo.jpg", .replaceFirst(find: "zzz", with: "b"))
        #expect(result == nil)
    }

    @Test("Ignore Case lets a replace match a different case")
    func replaceIgnoringCase() {
        let result = proposedName(
            "PHOTO.jpg", .replaceFirst(find: "photo", with: "image"),
            options: RenameOptions(ignoreCase: true))
        #expect(result == "image.jpg")
    }

    @Test("wildcard star matches a run and replaces the whole block")
    func wildcardStar() {
        let result = proposedName("IMG_0291.JPG", .wildcard(find: "IMG*.JPG", with: "photo.jpg"))
        #expect(result == "photo.jpg")
    }

    @Test("wildcard question mark matches exactly one character")
    func wildcardQuestionMark() {
        // "IMG_02??.JPG" matches IMG_0291.JPG but a single ? would not span two digits.
        #expect(
            proposedName("IMG_0291.JPG", .wildcard(find: "IMG_02??.JPG", with: "x"))
                == "x")
        #expect(
            proposedName("IMG_0291.JPG", .wildcard(find: "IMG_02?.JPG", with: "x"))
                == nil)
    }

    @Test("regex rearranges with $1 back-references")
    func regexBackReferences() {
        // Arrange: pull the number out and put it first.
        let result = proposedName(
            "IMG_0291.jpg", .regex(pattern: #"IMG_(\d+)"#, template: "shot-$1"))
        // Assert
        #expect(result == "shot-0291.jpg")
    }

    @Test("an invalid regex skips the row rather than throwing")
    func regexInvalidSkips() {
        let result = proposedName("photo.jpg", .regex(pattern: "(", template: "x"))
        #expect(result == nil)
    }

    @Test("a cached pattern still honours Ignore Case on each call")
    func regexCacheKeepsOptionsApart() {
        // The compiled-pattern cache must not hand a case-insensitive regex to
        // a case-sensitive call (or the reverse) for the same pattern text.
        let function = RenameFunction.regex(pattern: "abc", template: "x")
        let insensitive = RenameOptions(ignoreCase: true)
        #expect(proposedName("ABC", function, options: insensitive) == "x")
        #expect(proposedName("ABC", function) == nil)
        #expect(proposedName("ABC", function, options: insensitive) == "x")
    }

    @Test("a literal replace treats a regex metacharacter as plain text")
    func literalReplaceIsNotRegex() {
        // The "." is a literal dot, not "any character": only the dots change.
        let result = proposedName("a.b.c.txt", .replaceAll(find: ".", with: "-"))
        #expect(result == "a-b-c-txt")
    }

    @Test("wildcard escapes metacharacters in the pattern so they match literally")
    func wildcardEscapesPattern() {
        // The "." must match a real dot, not any character.
        #expect(proposedName("a.c", .wildcard(find: "a.c", with: "X")) == "X")
        // If "." were an unescaped regex wildcard, "axc" would match; it must not.
        #expect(proposedName("axc", .wildcard(find: "a.c", with: "X")) == nil)
    }

    @Test("wildcard treats $ in the replacement as literal, not a back-reference")
    func wildcardEscapesReplacement() {
        // Wildcards capture no groups, so "$1" must survive verbatim rather than
        // being expanded (or dropped) as a back-reference.
        let result = proposedName("IMG_1.JPG", .wildcard(find: "IMG*", with: "$1done"))
        #expect(result == "$1done")
    }
}
