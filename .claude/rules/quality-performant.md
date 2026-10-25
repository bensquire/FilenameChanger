---
title: Fast Where It Counts, and Measured
impact: HIGH
impactDescription: The plan reruns on every keystroke over every file in the list; everything else is written for the reader
tags: [quality, performance, plan, keystroke, metadata]
paths: ["Sources/RenameKit/**/*.swift", "Sources/RenameApp/AppModel.swift", "Sources/RenameApp/ContentView.swift"]
---

## Fast Where It Counts, and Measured

**Impact: HIGH**

The cost is in one place: the live plan. `AppModel.plan` reruns
`RenameEngine.plan` on every change to a parameter, so every keystroke in a
Find field plans every file in the list. Measured on 25 October 2026, release
build, 1,000 empty files in a temp folder: a Prepend plan 12 ms, a Regex plan
14 ms, a Date plan that reads each file's dates and EXIF 30 to 45 ms. The
engine keeps that cost down where it is decided:

- **Metadata is read only when used.** A file's dates and EXIF are a disk and
  ImageIO read; only a Date stamp from the file uses them (`readsMetadata`).
  Sequence's date sort reads each file's date once, not on every comparison.
- **Disk existence is read once a row,** before the collision fix-point loop,
  not inside it.
- **Patterns and formatters are built once.** `TextMatching` caches compiled
  regexes and `DateStamp` caches formatters, each in an `NSCache`.
- **The view plans once a render.** `ContentView.body` computes `model.plan`
  once and hands it to the table and the bottom bar.

The rename itself moves files in the same folder, which is a rename on the
volume, not a copy. It is not where the time goes.

Which code is hot is decided by measuring: `time` on a real folder, a plan over
1,000 files before and after. A comment on a fast path says what it cost before
and after. Prose code stays prose. A hot path does not do a per-row disk read
that a cheaper check could skip.

**Incorrect (the plan recomputed per view; the disk read per comparison):**

```swift
fileTable(model.plan); bottomBar(model.plan)   // two full plans per render
sorted = items.sorted { provider.metadata(for: $0.url).modificationDate ?? .distantPast
    < provider.metadata(for: $1.url).modificationDate ?? .distantPast }   // n log n reads
```

**Correct (once, and the reason kept):**

```swift
// Compute the plan once per render and hand it to the subviews, rather
// than recomputing it (disk + EXIF work) separately in each.
let plan = model.plan
```
