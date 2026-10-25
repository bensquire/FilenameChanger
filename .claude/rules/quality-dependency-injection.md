---
title: Dependencies and Settings Are Handed In as Values
impact: HIGH
impactDescription: Code that reaches for a global cannot be tested, varied or reused without it
tags: [quality, dependency-injection, values, testability]
paths: ["Sources/**/*.swift", "Tests/**/*.swift"]
---

## Dependencies and Settings Are Handed In as Values

**Impact: HIGH**

A type takes its collaborators and its settings as values, and whoever calls
it hands them in. `RenameEngine.plan(items:function:options:provider:)` takes
the function and `RenameOptions` as values and reads the disk only through a
`FileMetadataProvider`. `RenameSequencer.ordered(_:temporaryName:)` takes the
temporary name. `AppModel(provider:store:moveItem:)` takes the provider, a
`PersistenceStore` and the one call that moves a file.
`PersistenceStore(directory:)` takes its folder. `AppDelegate(model:)` takes
its model. The environment is read only at the edge: `AppDelegate.init()`, the
composition root, reads `FILENAMECHANGER_FOLDER` and builds the real model,
with `SystemFileMetadataProvider` and the store in Application Support.

Tests hand in a `FakeMetadataProvider` that says which names exist, a store in
a temp folder, a `moveItem` that fails on demand, and a counter for temporary
names. The one clock read inside the model is a history entry's date, which no
test checks. A feature that depends on time takes the clock as a value.

When a knob is added, it is added once, on the value that carries it: a
cross-cutting switch on `RenameOptions`, a function's own setting on its config
(`SequenceConfig`, `DateConfig`, `CleanUpConfig`). It is not mirrored as a
second flag on every caller.

**Incorrect (the disk and the clock reached for inside the engine):**

```swift
let taken = FileManager.default.fileExists(atPath: target.path)   // inside RenameEngine
let stamp = DateStamp.string(from: Date(), pattern: pattern)       // "today": untestable
```

**Correct:**

```swift
existsOnDisk[item.id] = provider.fileExists(at: targetURL(for: item, name: name))
let config = DateConfig(source: .custom(fixedDate), format: .preset(.isoDash))
```
