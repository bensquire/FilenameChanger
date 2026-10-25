---
title: Match the Code Around You
impact: HIGH
impactDescription: One idiom for one job, so a reader learns it once
tags: [quality, consistency, idioms, reuse]
paths: ["Sources/**/*.swift", "Tests/**/*.swift"]
---

## Match the Code Around You

**Impact: HIGH**

New code reads like the file it lands in: the same naming, comment density,
error style, and idioms. Why a row cannot be renamed is a `RenameIssue`, shown
through `issueText`. What went wrong on disk is a line in
`AppModel.renameFailures`, which drives the one alert.

Before writing a helper, look for the one that exists, and call it:

- `URL.caseFoldedPathKey`: the one collision rule the engine and the
  sequencer share.
- `RenameEngine.planOverride`: a single-file rename checked by the batch's
  rules.
- `RenameEngine.actionableRenames`: the rows that will really move.
- `FileAdder.expandForDrop`: folders walked for a drop, the Service and Open
  With alike.
- `RenameOptions.displayName(for:)`: a name with Hide Extensions applied.
- `NameDiff.attributed`: the changed part highlighted.
- `DateStamp.string(from:pattern:)`: a date in a pattern, with a cached
  formatter.
- `TextMatching`: literal, wildcard and regex replacement, with a cached
  compiled pattern.
- `PresetMenuItems`: the presets, for both the window's menu and the menu bar.
- `.hoverHighlight()`: hover feedback on a button.

In tests, `FakeMetadataProvider.swift` has the fake provider, `items(_:in:)`
for file items under a throwaway folder, and `proposedName(_:_:)` for a
one-file function test. The on-disk suites each build a private `Sandbox` (or
`TempDir`) of real files in a temp folder that removes itself. Three suites
now carry their own copy, which is the point to move one into a shared file
rather than write a fourth. A second spelling of the same thing is a bug
waiting for one of them to drift.

**Incorrect (a fresh spelling of an existing helper):**

```swift
// AppDelegate, for Open With
let files = urls.flatMap {
    (try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? [$0]
}   // walks one level, keeps .DS_Store, opens up .app bundles
model.add(urls: files)
```

**Correct:**

```swift
model.add(urls: FileAdder.expandForDrop(urls))
```
