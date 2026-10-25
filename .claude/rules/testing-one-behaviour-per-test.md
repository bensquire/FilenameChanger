---
title: One Behaviour Per Test, Named as a Sentence
impact: HIGH
impactDescription: A test of several things fails for one and hides the rest
tags: [testing, naming, scope, swift-testing]
paths: ["Tests/**/*.swift"]
---

## One Behaviour Per Test, Named as a Sentence

**Impact: HIGH**

A test pins one behaviour, and its display name says which, as a sentence the
report prints: `@Test("a swap renames both files through a temp, content
intact")`, `@Test("Force Unique steps past a name that already exists on
disk")`, `@Test("hidden files such as .DS_Store are never queued")`. The
function name is a short camel-case handle (`swapRenamesBothFiles`). A
`@Suite("…")` names the subject. A name with "and" in it that lists unrelated
checks is usually two tests. A name with "and" that describes one observable
outcome is fine.

When the same behaviour is asked of several inputs, pass them as `arguments:`
to one `@Test`, rather than copy the test or loop inside it, as
`emptiedNameIsInvalid(function:)` and the date presets do. Each argument then
passes or fails on its own, with the argument in the report.

Test the behaviour, not the implementation: what the plan proposes, what is on
disk afterwards, what the alert lists, not which private function ran.
`@testable` is for reaching a real internal seam, not for asserting on
scaffolding.

**Incorrect:**

```swift
@Test func sequenceWorks() {
    // checks numbering, padding, the date sort, a skipped row and Force Unique in one go
}
```

**Correct:**

```swift
@Test("a shift onto names the batch vacates is allowed, not flagged")
func shiftChainAllRename() { … }

@Test("a swap cycle is allowed, not flagged as a mutual collision")
func swapCycleAllRename() { … }

@Test("a function that empties the name is flagged invalid, never a hidden \".ext\"",
    arguments: [RenameFunction.removeCharacters(.fromEnd(count: 5)), .replaceAll(find: "ab", with: "")])
func emptiedNameIsInvalid(function: RenameFunction) { … }
```
