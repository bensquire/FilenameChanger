---
title: A Change Is Checked, Not Believed
impact: CRITICAL
impactDescription: A unit test proves a fake folder; only real files show what a user's folder becomes
tags: [workflow, verification, tests, lint, rename]
paths: ["Sources/**", "Tests/**", "Package.swift", "bundle.sh", "scripts/**"]
---

## A Change Is Checked, Not Believed

**Impact: CRITICAL**

Before saying a change is done:

1. **`make lint`**: `swift format lint --strict` over `Sources`, `Tests` and
   `Package.swift`, as CI and the pre-commit hook run it. About a quarter of a
   second.
2. **`make test`**, the whole suite: `swift test`, a debug build, which is fine
   because the engine is light. With the build warm it takes about 2 s; from
   clean about 21 s.
3. **The real thing**, for anything touching a function, the plan, the moves or
   the file list: rename real files in a throwaway folder, never the user's
   originals. Use the relaunched app, driven by the `run-filenamechanger`
   skill, or `FILENAMECHANGER_FOLDER=/path swift run FilenameChanger`. Check
   the New Name column and the grey rows, press Rename, then check the folder
   (`ls -la`): the names are right, the contents moved with them, and no
   `.filenamechanger-rename-…` file is left. Then ⌘Z, and check every name is
   back. For an EXIF date, use real photos; the tests use none.
4. **The bundle**, when `bundle.sh`, `scripts/Info.plist.template` or a target
   changes: `CODESIGN_IDENTITY=- ./bundle.sh`, as CI's smoke step does, and
   check `FilenameChanger.app/Contents/MacOS/FilenameChanger` is there and
   `du -sh FilenameChanger.app`. The Finder Service and Open With need the
   bundle: `swift run` has no `Info.plist`, so neither is registered.

Report what was run and what it showed. A check that was skipped is named as
skipped, not left out.

**Incorrect (one suite, no lint, no real files):**

```
Ran EngineTests; passes. Done.
```

**Correct:**

```
lint clean; 103 tests pass in 1.5 s. In the app, a copy of ~/Desktop/trip (40
photos): Sequence by EXIF date numbered them 001–040 in shot order, the
folder holds 40 files with no temporary left, and ⌘Z put every name back.
```
