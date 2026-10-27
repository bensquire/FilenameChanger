---
name: run-filenamechanger
description: Run and drive FilenameChanger, the macOS batch file renamer, through its UI. Use when asked to start or relaunch the app, take a screenshot of its window, click through it (choose a function, type into a field, press Rename, undo, open a sheet), or confirm a change works in the real app on throwaway files. Building, testing and linting without the UI is the build skill.
---

# Running FilenameChanger

Drive the bundled app with `.claude/skills/run-filenamechanger/driver.sh`, run
from the repo root. It reads and presses controls through the Accessibility
API (`ax.swift`, a small helper it compiles on first use), types and clicks
menus through System Events, and screenshots the window with
`screencapture -l`. The `build` skill covers building, the suite and lint on
their own.

## Prerequisites

The terminal running the agent needs **Accessibility** permission (to read,
press and type) and **Screen Recording** permission (to screenshot), both under
System Settings → Privacy & Security. Ghostty on this Mac has both. To check
the first, run this; it should print `true`:

```bash
osascript -e 'tell application "System Events" to get UI elements enabled'
```

Without Screen Recording, a screenshot is a few kilobytes of solid colour.

## Run (agent path)

Each command does one thing, then prints the app's state, which you read to
decide the next step: each pop-up and text field with its value, every row as
`[x] old -> new`, and the count under the list; or, while a sheet is up, its
words and buttons. Output goes in `$FILENAMECHANGER_RUN_DIR`, by default
`$TMPDIR/filenamechanger-run/`.

This flow renames the fixture files, checks them on disk and undoes it:

```bash
D=.claude/skills/run-filenamechanger/driver.sh
$D build
$D launch "$($D fixture)"
$D pick "Rename function" Prepend
$D type Text "2026 - "       # rows read: [x] IMG_0001 -> 2026 - IMG_0001
$D press Rename
$D files                     # 2026 - IMG_0001.JPG …
$D menu Edit Undo            # takes back the typing (see Gotchas)
$D menu Edit Undo            # takes back the rename
$D files                     # IMG_0001.JPG …
$D ss after-undo             # then Read the PNG it prints
$D quit
```

| command | what it does |
|---|---|
| `build` | `CODESIGN_IDENTITY=- ./bundle.sh`, about 12 s warm |
| `fixture` | Makes `$FILENAMECHANGER_RUN_DIR/files` afresh with four empty files (`IMG_0001.JPG`, `IMG_0002.JPG`, `holiday notes.txt`, `Report FINAL v2.pdf`) and prints its path |
| `launch [folder]` | Quits any running copy, opens the app with the folder's files loaded, and waits for the window. Presets and history go to `$FILENAMECHANGER_RUN_DIR/store`, never the user's own |
| `state` | Prints the state, or `not running` |
| `tree` | Prints every element in the window, or the sheet, with label, value and `(disabled)`: the way to find a label |
| `pick <pop-up> <item>` | Chooses from a pop-up, given by label (`"Rename function"`), number in window order, or current value (`"Title Case"`) |
| `press <control>` | Presses a button, checkbox, tab or menu button by label or number: `Rename`, `"Add Step"`, `History`, `Done`, `"Force unique"`, `"Include IMG_0001.JPG"` |
| `type <field> <text>` | Replaces a text field's contents, the field given by label (`Text`, `Find`, `Template`) or number, and reads it back |
| `menu <menu> <item>` | Clicks a menu item: `menu Edit Undo`, `menu File "Remove All Files"`. Titles are exact, `…` included |
| `ss [name]` | Screenshots the window to `$FILENAMECHANGER_RUN_DIR/<name>.png`, 1,400 px wide, even behind other windows |
| `files [folder]` | Lists the folder on disk, the fixture by default |
| `quit` | Quits the app and waits until it has gone |

An unknown label fails with the list of labels there are. For your own sample
files (real photos for an EXIF date, PDFs for Smart Name), make a throwaway
folder in the scratchpad and pass it to `launch`; never the user's own files.

## Run (human path)

```bash
pkill -x FilenameChanger; open FilenameChanger.app
```

The `workflow-hand-over-for-trial` rule says what to tell the user.

## Gotchas

- **Launch through the driver.** It sets `FILENAMECHANGER_STORE`; a bare
  `open` writes every trial rename into the user's real History.
- **System Events can't name SwiftUI's controls.** It calls most of them
  "button". SwiftUI puts the label in `AXDescription` or `AXHelp`, which
  `ax.swift` reads. A control with no label at all, such as the Case pop-up, is
  reached by number or current value; `.accessibilityLabel` in the view fixes
  that for VoiceOver too, as the text fields have.
- **Setting a text field's value doesn't reach the model.** `AXValue` changes
  what the field shows but not its binding, and the stale text was once
  committed later. `type` focuses the field through `AXFocused`, then sends ⌘A
  and the keys through System Events.
- **Keystrokes go to whichever app is in front.** `type` and `menu` bring the
  app forward and refuse if its window isn't on screen (another Space); `type`
  checks again in the script that sends the keys, then reads the field back.
- **Undo takes back typing before a rename.** Pressing controls through
  Accessibility doesn't move focus, so after `type` the field still has it, and
  the first `menu Edit Undo` undoes the typing. Undo again, and check with
  `files`.
- **AXPress on a menu bar item does nothing.** It reports success, but the
  closed menu never validates the item. `menu` clicks through System Events.
- **A pop-up leaves a hidden 500 × 500 window behind** that screenshots blank
  white. `ax window` matches the real window by its frame.
- **`open` brings an already-running copy forward** instead of starting this
  build; one in `/Applications` has the same bundle identifier. `launch` quits
  any copy first.
- **AppleScript reserved words:** a variable named `front` or `before` fails
  with a confusing error (`Can't set insertion point 1 to …`).
