---
title: Diagnostics Are Gated to Keep, Separate to Throw Away
impact: MEDIUM
impactDescription: A debug block woven into the engine has to be edited out of the engine
tags: [workflow, diagnostics, environment, logging]
paths: ["Sources/**"]
---

## Diagnostics Are Gated to Keep, Separate to Throw Away

**Impact: MEDIUM**

A switch worth keeping is an environment variable named `FILENAMECHANGER_*`,
read once, at the composition root, and handed in as a value.
`FILENAMECHANGER_FOLDER` is read in `AppDelegate.init()`, which lists the
folder and hands the files to `model.add(urls:)`, so the model itself stays
environment-free. Diagnostics for one investigation go in a separate file,
marked temporary, and are deleted before handover. They are never woven into
`RenameEngine.plan` or `AppModel.applyMoves`, where stripping them means
editing the code that renames.

There is no helper and no protocol on standard output here, so a temporary
`print` under `swift run` is harmless. The bundled app opened from Finder has
nowhere to print to; a diagnostic needed from it goes to `os.Logger`, read
with `log stream`, and comes out with the rest before handover.

**Incorrect (a dump inline in the plan, run on every keystroke):**

```swift
if ProcessInfo.processInfo.environment["DEBUG_PLAN"] != nil {
    print(item.originalName, proposedNames[item.id] ?? "-")   // inside RenameEngine.plan, per row
}
```

**Correct (its own file, one call, one deletion; the switch read at the root):**

```swift
// Sources/RenameApp/Debug.swift — TEMPORARY, not for commit
func dumpPlan(_ plan: [PlannedRename]) { … }

// AppDelegate.init(), the composition root
if let path = ProcessInfo.processInfo.environment["FILENAMECHANGER_FOLDER"] { … }
```
