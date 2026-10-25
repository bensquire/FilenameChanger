# FilenameChanger

FilenameChanger is a native macOS batch file renamer, a recreation of MRR
Software's NameChanger in SwiftUI. The user adds files, picks one of thirteen
rename functions, and the New Name column shows every result as they type. Two
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
| `Sources/RenameKit` | The engine: the thirteen functions as `RenameFunction` cases, `RenameEngine` (the plan and its collision rules), `RenameSequencer` (orders chained moves through temporary names), `TextMatching`, and `SystemFileMetadataProvider` (file dates and EXIF through ImageIO). No AppKit or SwiftUI, and it moves no files. |
| `Sources/RenameApp` | The `@MainActor @Observable AppModel`, which alone moves files, and the views. Also the edges to the system: `AppDelegate` (Open With, the Dock icon, the Finder Service, `FILENAMECHANGER_FOLDER`), `FileAdder` (open panel, drops, folder walks), `FileCommands` (the File menu) and `Persistence` (presets and history as JSON). A library, so the model is testable. |
| `Sources/FilenameChanger` | The `@main` scene and nothing else. |
| `Tests/FilenameChangerTests` | Swift Testing (`@Test`, `#expect`), not XCTest. Engine tests use `FakeMetadataProvider` and never touch the disk; the on-disk suites rename real files in temp folders. |
| `icon/`, `scripts/` | The icon generator and `.icns`; `Info.plist.template` (the Service, the document type), `make-dmg.sh`, `repack-icns.py`. |

No dependencies; swift-tools 6.2, macOS 26. There is no MCP server, socket,
helper binary, URL scheme or second executable.

## Commands

```
make lint       # swift format lint --strict over Sources, Tests, Package.swift
make test       # swift test: the whole suite, debug build, about 2 s warm
make format     # swift format in place; run it over the files you changed
make bundle     # ./bundle.sh: build, strip, sign FilenameChanger.app
CODESIGN_IDENTITY=- ./bundle.sh                         # ad-hoc signed, as CI's smoke step
FILENAMECHANGER_FOLDER=/path swift run FilenameChanger  # start with that folder's files
```

`swift run` has no `Info.plist`, so the Finder Service and Open With need the
bundle.

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
