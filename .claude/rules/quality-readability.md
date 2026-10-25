---
title: Code Reads Like the Prose Around It
impact: HIGH
impactDescription: The next reader is a person, usually months later, often the author
tags: [quality, readability, naming]
paths: ["Sources/**/*.swift", "Tests/**/*.swift"]
---

## Code Reads Like the Prose Around It

**Impact: HIGH**

Names say what a thing is in the words the domain uses, the words the user
sees in the app: `proposedName`, `willRename`, `actionableRenames`,
`forceUnique`, `hideExtension`, `refersToItself`, `isExpandableDirectory`. A
call site then reads as a sentence. Short names are right where the convention
uses them (`ns` for an `NSString`, `ext`, `i`) and wrong anywhere else. A
function does what its name says and nothing more; one that needs "and" in its
name is two. Nesting is shallow; the early `guard` says what a function
refuses. A trick that needs a comment to decode earns its place only when it is
necessary, and then the comment says why, as the collision fix-point loop's
does.

**Incorrect:**

```swift
func chk(_ n: String, _ i: FileItem, _ p: FileMetadataProvider) -> Bool {
    if n.lowercased() != i.originalName.lowercased() { if !p.fileExists(at: …) { /* … */ } }
    return true
}
```

**Correct:**

```swift
/// Whether `name` is free for `item`: the file's own name, or a destination
/// no other row in the batch claims and nothing on disk holds.
private static func isAvailable(
    _ name: String, for item: FileItem, batchSources: Set<String>,
    provider: FileMetadataProvider
) -> Bool {
    if refersToItself(name, item) { return true }
    guard !batchSources.contains(collisionKey(for: item, name: name)) else { return false }
    return !provider.fileExists(at: targetURL(for: item, name: name))
}
```
