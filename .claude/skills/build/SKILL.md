---
name: build
description: Build, test, lint and bundle FilenameChanger — the SwiftPM package for the macOS batch file renamer — and what the release path does. Use when building or running the app, running the suite or one test, linting or formatting, bundling FilenameChanger.app for a trial, or asked how a release is cut.
---

# Building FilenameChanger

FilenameChanger is a SwiftPM package with no Xcode project and no dependencies.
`Package.swift` (tools 6.2, macOS 26) has one executable, `FilenameChanger`,
over the libraries `RenameKit` (the engine), `RenameIntelligence` (Smart Name's
document reader) and `RenameApp` (the SwiftUI views and model), plus one test target, `FilenameChangerTests`, using Swift Testing.
There are no other executables and no products. `bundle.sh` turns the
executable into `FilenameChanger.app`.

## Prerequisites

- Xcode 27 (Swift 6.4): Smart Name uses `LanguageModelError`, which is in the
  macOS 27 SDK, so Xcode 26 fails to compile `DocumentSummarizer.swift`. The
  app still runs on macOS 26. CI pins Xcode 27.1 on GitHub's `xcode-27`
  runner, a preview image, the same Xcode as this Mac; the `macos-26` runner
  has only Xcode 26.
- `swift format` ships with the toolchain; nothing to install for lint.
- For a Developer ID bundle: the "Developer ID Application" identity in the
  login keychain. Without it, sign ad hoc (below).
- For icon work only: `python3` for `scripts/repack-icns.py`, `pngquant` and `oxipng`
  (Homebrew) to optimise the iconset PNGs.

## Commands

Timings are from this Mac, 25 October 2026.

| What | Command | Notes |
|---|---|---|
| Debug build | `swift build` | `.build/debug/FilenameChanger`; about 15 s from clean |
| Run unbundled | `swift run FilenameChanger` | `FILENAMECHANGER_FOLDER=/path swift run FilenameChanger` loads that folder's top-level files at launch. No `Info.plist`, so no Finder Service and no Open With |
| Test suite | `make test` | `swift test`, a debug build: 169 tests in 21 suites, run in about 0.3 s; 2–3 s wall clock warm, about 21 s from clean. The first run after a reboot can take a minute while Vision loads its text-recognition model for the two OCR tests |
| One test | `swift test --filter swapRenamesBothFiles` | a suite's type name (`EngineTests`) or a test's function name. A `@Test("…")` display name does not match |
| Lint | `make lint` | `swift format lint --strict` over `Sources`, `Tests`, `Package.swift`; warnings fail; 0.2 s |
| Format | `make format` | rewrites in place; run it over the files you changed |
| Bundle | `make bundle` | `./bundle.sh` → `FilenameChanger.app` at the repo root (git-ignored), signed with Developer ID. See "Things that bite" |
| Bundle, ad hoc | `CODESIGN_IDENTITY=- ./bundle.sh` | what CI's smoke step runs; `VERSION=1.2.3` sets the version (default 0.1.0) |
| Launch | `pkill -x FilenameChanger; open FilenameChanger.app` | quit first: `open` only brings an already-running copy forward. `open --env FILENAMECHANGER_FOLDER=/path FilenameChanger.app` passes the folder. The `run-filenamechanger` skill launches and drives it |
| Icon | `swift icon/makeicon.swift && iconutil -c icns icon/FilenameChanger.iconset -o icon/FilenameChanger.icns` | then shrink it: `pngquant --quality 80-100` each PNG (the `quality-images-minified` rule has the loop), `oxipng -o max --strip safe icon/FilenameChanger.iconset/*.png` and `python3 scripts/repack-icns.py icon/FilenameChanger.icns icon/FilenameChanger.iconset icon/FilenameChanger.icns` (the `quality-images-minified` rule) |
| Clean | `make clean` | `swift package clean`, and removes the app, DMG and `dist/` |

What `bundle.sh` does, in order: `swift build -c release -Xswiftc -Osize`,
with `-emit-const-values` and the protocol list in
`scripts/const_extract_protocols.json` (about 18 s from clean, 12 s warm);
copies the executable into `Contents/MacOS`; runs Xcode's
`appintentsmetadataprocessor` twice (RenameApp, then the executable, merging
RenameApp's) to write `Contents/Resources/Metadata.appintents`, which is how
Shortcuts finds the actions; strips the executable; copies
`icon/FilenameChanger.icns`; writes `Info.plist` from
`scripts/Info.plist.template` with the version and checks it with `plutil`;
signs the app with the hardened runtime and a timestamp; and verifies the
signature. The result is 972 KB (`du -sh`): the executable 900 KB, the icon
40 KB, the metadata 20 KB. Check the actions landed with
`plutil -p FilenameChanger.app/Contents/Resources/Metadata.appintents/extract.actionsdata | grep Intent`.

## Matching CI

`.github/workflows/ci.yml` runs on pushes to `main` (not on `v*` tags), on
non-draft pull requests, and by hand. It skips Markdown-only, `images/`,
`LICENSE` and `.gitignore` changes. It runs `make lint`, `make test`, then
`CODESIGN_IDENTITY=- ./bundle.sh`, and checks the app's executable exists.
Those three locally are a CI run, except that CI skips the two OCR tests:
Vision can't compile its text-recognition model on GitHub's virtual machines,
so they are disabled when `GITHUB_ACTIONS` is set.

`.githooks/pre-commit` runs `make lint` and `make test`. It is active only once
`git config core.hooksPath .githooks` is set in a clone, and it is not set in
the working copy on this Mac.

Claude Code's own hook is separate: `.claude/settings.json` runs
`.claude/hooks/swift-format.sh` after every Edit or Write. On a `.swift` file
it formats the file in place, then lists the lines still over
`.swift-format`'s `lineLength` and exits 2, which is advice rather than a
block. Four lines in `Sources` are already over, so editing their files
reports them.

## Things that bite

- **Release flags and the build cache.** `bundle.sh`'s release build passes
  the const-values flags; a `swift build -c release` without them rebuilds
  every module, and so does the next `bundle.sh`. Use `bundle.sh` for release
  builds.
- **Shortcuts only runs a Developer ID build.** An ad-hoc bundle lists the
  actions, but running one fails with "Shortcuts couldn't communicate with the
  app". Use `make bundle`, and launch the app once normally: an app that has
  never been opened, or sits in a temp folder, isn't indexed.
- **Shortcuts hands Finder files over as `/.nofollow/…`** (macOS 27.0.1).
  `IntentFile.originalFileURL` strips it; use it rather than `fileURL`.

- **The certificate spells the name `SOUIRE`.** `bundle.sh`'s default identity
  matches it, as PaperPress's does. "Correct" it to `SQUIRE` and `codesign`
  stops with "no identity found".
- **The Finder Service caches.** After changing `NSServices` in the plist,
  Finder may show the old menu until `/System/Library/CoreServices/pbs -update`
  runs or you log out and in.
- **A second copy answers instead.** A FilenameChanger in `/Applications` has
  the same bundle identifier, so `open` and the Service can reach it rather
  than the fresh build. Quit both, or open this one by path.

## Releasing

Run this only when the user asks for a release. Pushing a `v*` tag runs
`.github/workflows/release.yml`: lint and test, import the Developer ID
certificate into a throwaway keychain, `bundle.sh` with the tag's version,
notarise and staple the app, build the DMG with `scripts/make-dmg.sh`, sign,
notarise and staple it, write notes from `git log` since the previous tag, and
publish a GitHub Release with the DMG. A tag with a suffix (`v0.2.0-rc1`)
publishes as a prerelease. It needs the six repository secrets listed in the
workflow header. Locally, `make release` runs `release.sh`: `bundle.sh` (so the
identity note above applies), then `scripts/make-dmg.sh` to
`FilenameChanger.dmg`, notarised and stapled if the `paperdrop` notarytool
keychain profile is stored.
