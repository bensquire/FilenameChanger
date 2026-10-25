---
title: Offline, Nothing Overwritten, Nothing Stranded
impact: HIGH
impactDescription: A renamer that overwrites a file, leaves one half-renamed, or talks to the network has broken trust
tags: [quality, security, privacy, network, files, rename]
paths: ["Sources/**/*.swift", "bundle.sh", "release.sh", "scripts/**", "Package.swift"]
---

## Offline, Nothing Overwritten, Nothing Stranded

**Impact: HIGH**

- **Offline.** No network requests and no telemetry; the README promises it
  works offline. Nothing in the package links `Network` or opens a URL session.
  A feature that needs a remote host is a product decision for the user,
  raised before it is built.
- **No way in but the user's.** Files arrive only from the user: the open
  panel, a drop, Open With, and the Finder Service, which reads file URLs only
  (`.urlReadingFileURLsOnly`). There is no socket, no helper, no URL scheme and
  no child process.
- **Nothing is overwritten.** Every move goes through the one injected
  `moveItem`, which is `FileManager.moveItem`, and that never replaces an
  existing file. The plan flags a name that is taken, wanted twice, empty,
  `.`, `..` or contains `/`, before anything moves. A case-only rename is the
  file itself, not a clash.
- **Nothing is stranded.** A batch is ordered by `RenameSequencer`, so a chain
  or a swap never lands on a file that has not moved yet. A cycle goes through
  a hidden temporary name in the same folder. If any move fails, the moves
  already made are put back, newest first. A file that cannot be put back is
  named in the alert with where it was left. Undo replays the inverse moves.
- **Settings are never lost.** `PersistenceStore` writes atomically, and a
  presets or history file that will not decode is moved aside to `.bak`, not
  overwritten by the next save.
- **Signed and hardened.** `bundle.sh` signs with the hardened runtime and a
  timestamp; `release.yml` notarises the app and the DMG. The app is not
  sandboxed, so the checks above are what stand between a mistake and the
  user's files.

**Incorrect:**

```swift
try? FileManager.default.removeItem(at: to)        // whatever was at `to` is gone
try FileManager.default.moveItem(at: from, to: to)
```

**Correct:**

```swift
let ordered = RenameSequencer.ordered(moves)       // chains and swaps via a temp name
let failures = applyMoves(ordered, undoManager: undoManager, actionName: "Rename")
// moveItem refuses an existing destination; a failure rolls the batch back
```
