---
title: Ground Truth Is the Files on Disk, and the Bar Has Teeth
impact: HIGH
impactDescription: A model that says "renamed" can sit over a folder where a file was clobbered, swapped back or left under a temporary name
tags: [testing, ground-truth, disk, rename, fixtures]
paths: ["Tests/**/*.swift"]
---

## Ground Truth Is the Files on Disk, and the Bar Has Teeth

**Impact: HIGH**

For the engine, the plan is the truth: `RenameEngine` is pure, and a test
checks the names and issues it proposes. For anything that moves files, the
truth is the folder afterwards. A fixture is a set of real files with known
contents (`"TWO"`, `"ONE"`, `"PRECIOUS"`), so the result can be judged by
reading the folder back. Check which names exist and which are gone, that each
name holds the bytes it should, and that no `.filenamechanger-rename-…` file is
left. The model's state (`items`, `history`, `renameFailures`) is checked too,
but it is not the proof.

Where it can, a test also states what the alternative would have measured, so
the bar cannot be cleared by accident. `collisionDoesNotClobberContents` checks
that the existing file keeps its own bytes and the source keeps its own, not
just that both names still exist. `swapRenamesBothFiles` checks contents, so a
swap that moved both names but left each file's bytes where they were would
fail. `failedRollbackIsReported` makes a move fail on purpose and checks where
the file really is, and that the table points there. When a bug is fixed, a
test pins it, with the case that showed it.

**Incorrect (a bar with no teeth — passes on a folder that was clobbered):**

```swift
model.performRename(undoManager: nil)
#expect(model.renameFailures.isEmpty)
#expect(sandbox.exists("1.txt") && sandbox.exists("2.txt"))   // both names exist either way
```

**Correct (the files themselves, and the alternative ruled out):**

```swift
#expect(sandbox.contents(of: "1.txt") == "TWO")  // old 2.txt's bytes
#expect(sandbox.contents(of: "2.txt") == "ONE")  // old 1.txt's bytes
let leftovers = try FileManager.default.contentsOfDirectory(atPath: sandbox.directory.path)
    .filter { $0.hasPrefix(".filenamechanger-rename") }
#expect(leftovers.isEmpty)
```
