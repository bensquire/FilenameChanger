# FilenameChanger

FilenameChanger is a native macOS batch file renamer, a recreation of MRR
Software's NameChanger in SwiftUI. The user adds files, picks one of fourteen
rename functions (or a chain of them, run in order), and the New Name column
shows every result as they type. Two
promises follow from that, and every change is held to them:

- **Nothing moves until Rename.** Every new name is planned first, and a row
  that would collide, or whose name is empty or invalid, is shown grey with the
  reason and skipped.
- **No file is overwritten or stranded.** A move never replaces an existing
  file. Chains and swaps go through a temporary name, a failed batch is put
  back, and ⌘Z undoes the whole batch.

## Layout

| Target | What it is |
|---|---|
| `Sources/RenameKit` | The engine: the fourteen functions as `RenameFunction` cases, `RenameEngine` (the plan and its collision rules), `RenameSequencer` (orders chained moves through temporary names), `TextMatching`, and `SystemFileMetadataProvider` (file dates and EXIF through ImageIO). No AppKit or SwiftUI, and it moves no files. Smart Name's findings arrive as `FileMetadata.document`, so the engine stays synchronous. |
| `Sources/RenameIntelligence` | Smart Name's reader. `DocumentText` gets the text (the PDFKit text layer, Vision OCR for scans and images, plain text), and `AppleIntelligenceSummarizer` asks the on-device Foundation Models model for a title, sender, type and date behind the `DocumentSummarizer` protocol. On device only, no Private Cloud Compute. |
| `Sources/RenameApp` | The `@MainActor @Observable AppModel`, which alone moves files, and the views. Also the edges to the system: `AppDelegate` (Open With, the Dock icon, the Finder Service, `FILENAMECHANGER_FOLDER`), `FileAdder` (open panel, drops, folder walks), `FileCommands` (the File menu), `Persistence` (presets and history as JSON), `DocumentAnalysis` (Smart Name's queue, which reads each row once, keyed by row id), `FileMover` (the all-or-nothing moves and the folders Smart Name files into), `FunctionSettings` (one step as the panel edits it) and `ShortcutsActions` (the App Intents actions, which rename through `AppModel.rename(_:steps:options:)` without touching the window). A library, so the model is testable. |
| `Sources/FilenameChanger` | The `@main` scene, and the `AppShortcutsProvider`, which App Intents only finds in the executable. |
| `Tests/FilenameChangerTests` | Swift Testing (`@Test`, `#expect`), not XCTest. Engine tests use `FakeMetadataProvider` and never touch the disk; the on-disk suites rename real files in temp folders. |
| `icon/`, `scripts/` | The icon generator and `.icns`; `Info.plist.template` (the Service, the document type), `make-dmg.sh`, `repack-icns.py`, and `const_extract_protocols.json`, which `bundle.sh` hands swiftc so the App Intents metadata can be extracted. |

No dependencies; swift-tools 6.2, macOS 26. There is no MCP server, socket,
helper binary, URL scheme or second executable. The one way in from outside
is the Shortcuts actions, run from shortcuts the user builds.

## Commands

```
make lint       # swift format lint --strict over Sources, Tests, Package.swift
make test       # swift test: the whole suite, debug build, about 2 s warm
make format     # swift format in place; run it over the files you changed
make bundle     # ./bundle.sh: build, strip, sign FilenameChanger.app
CODESIGN_IDENTITY=- ./bundle.sh                         # ad-hoc signed, as CI's smoke step
FILENAMECHANGER_FOLDER=/path swift run FilenameChanger  # start with that folder's files
```

`swift run` has no `Info.plist`, so the Finder Service, Open With and the
Shortcuts actions need the bundle. Shortcuts only runs the actions from a
Developer ID build (`make bundle`) launched once normally; an ad-hoc one lists
them but "couldn't communicate with the app".

## Where the rest lives

- `.claude/rules/`: one rule per file, grouped by section: workflow, quality,
  testing, native, communication. `README.md` there is the index and
  `_template.md` the shape of a new one. A rule with `paths` loads itself when
  a matching file is in play.
- `.claude/skills/apple-docs/`: how to ask `scrapple`, the offline index of
  Apple's documentation, WWDC transcripts and sample code. Look there before
  using a system API or building what the system already has.
- `.claude/skills/build/`: building, testing, linting, bundling and releasing,
  with prerequisites, timings, what CI and the pre-commit hook run, and what
  bites.
- State: presets and history persist as `presets.json` and `history.json` in
  `~/Library/Application Support/FilenameChanger/`; an unreadable one is kept
  as `.bak`. The file list, the chosen function and the options start fresh at
  every launch, so a relaunch is a clean trial. The app is not sandboxed.
