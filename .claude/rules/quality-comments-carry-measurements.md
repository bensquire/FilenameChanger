---
title: A Comment Is Short, and Says Why
impact: HIGH
impactDescription: A comment costs every reader time and every token money; it earns that or it goes
tags: [quality, comments, documentation, measurements, brevity]
paths: ["Sources/**/*.swift", "Tests/**/*.swift"]
---

## A Comment Is Short, and Says Why

**Impact: HIGH**

A comment adds what the code cannot say — why this, what was measured, what was
rejected — in as few plain words as will still read. It does not restate a
method or property name. A claim carries its measurement: the folder or
fixture, before, after. A constant carries the reason that set it. Where a
decision rests on Apple's documentation, the page's path goes in the comment
(`/documentation/appkit/nsapplication/servicesprovider`). No flourish, no
anecdote told twice, no comment about code that has gone.

The code's comments already say why: `TextMatching` names the reason for
`NSRegularExpression` over `Regex`, `RenameSequencer.temporaryName` says the
temporary name stays in the same folder so the move is never a cross-device
copy, and `FileAdder` says why hidden files are skipped. What they mostly lack
is the number. A comment about speed carries the figure that was measured.

**Incorrect (restates the name; no number; flowery):**

```swift
/// Whether we read metadata.
let readsMetadata = function.readsMetadata

/// After a lot of careful thought we realised that reading metadata for every
/// file could get really quite slow in big folders …
```

**Correct (the why and the number, then stop):**

```swift
// Metadata is a disk + ImageIO read per file, and the plan reruns on every
// keystroke; only a Date stamp uses it, so skip it for everything else.
// 1,000 files, release build: a Prepend plan 12 ms, a file-date plan 45 ms.
let readsMetadata = function.readsMetadata
```
