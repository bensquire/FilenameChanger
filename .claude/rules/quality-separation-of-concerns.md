---
title: Each Part Does One Job, and Knows Only Its Neighbours
impact: HIGH
impactDescription: The engine is tested headlessly against a fake because nothing in it knows about a window or the disk directly
tags: [quality, architecture, separation-of-concerns, layers]
paths: ["Sources/**/*.swift", "Package.swift"]
---

## Each Part Does One Job, and Knows Only Its Neighbours

**Impact: HIGH**

The layers are the targets in `Package.swift`, and the dependencies run one way:

- **`RenameKit`** is the engine: the thirteen functions (`RenameFunction`), the
  plan with its collision rules (`RenameEngine`), the move ordering
  (`RenameSequencer`), matching (`TextMatching`) and the real metadata reader
  (`SystemFileMetadataProvider`). It imports Foundation and ImageIO, no AppKit
  or SwiftUI, and it moves no files: it says what should happen.
- **`RenameApp`** holds the `@MainActor @Observable AppModel`, the views, and
  the edges to the system: `FileAdder` (the open panel and folder walks),
  `Persistence` (presets and history as JSON) and `AppDelegate` (Open With,
  the Dock icon and the Finder Service). It is a library so the model can be
  tested.
- **`FilenameChanger`** is the `@main` scene and nothing more.

Within the engine, `RenameFunction` turns one base name into a proposed one,
`RenameEngine` decides which rows may move, `RenameSequencer` orders the moves,
and values (`FileItem`, `RenameOptions`, `PlannedRename`, `MoveOp`) flow
between them. `AppModel.performRename` is the one place that moves files. A
change that needs `RenameKit` to import a UI framework, a view to decide a
collision, or the engine to call `FileManager` directly is at the wrong layer.

**Incorrect (a view deciding something the engine owns):**

```swift
// ContentView
let clash = model.items.contains { $0.originalName.lowercased() == row.proposedName.lowercased() }
```

**Correct (the engine states the rule; the view shows it):**

```swift
// RenameKit: the plan row carries .issue (.collision, .duplicateResult, .invalidName)
// ContentView, through issueText
if let issue = row.issue { … .help(issueText(issue)) }
```
