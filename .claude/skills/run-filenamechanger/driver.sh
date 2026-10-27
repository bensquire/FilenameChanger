#!/bin/bash
# Builds, launches and drives FilenameChanger.app through the Accessibility API
# (ax.swift) and System Events, and screenshots its window. Run from the repo root:
#   .claude/skills/run-filenamechanger/driver.sh <command> [args]
# Commands are listed in SKILL.md and by `driver.sh help`.
set -euo pipefail

RUN_DIR="${FILENAMECHANGER_RUN_DIR:-${TMPDIR:-/tmp}/filenamechanger-run}"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$PWD/FilenameChanger.app"
# Read where bundle.sh reads it, so the two can't drift.
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw scripts/Info.plist.template)
export FILENAMECHANGER_BUNDLE_ID="$BUNDLE_ID"

# ax.swift, compiled into $RUN_DIR on first use and again whenever it changes.
ax() {
  local tool="$RUN_DIR/ax"
  if [ ! -x "$tool" ] || [ "$SKILL_DIR/ax.swift" -nt "$tool" ]; then
    mkdir -p "$RUN_DIR"
    swiftc -O "$SKILL_DIR/ax.swift" -o "$tool" 2>/dev/null
  fi
  "$tool" "$@"
}

wait_for() { # wait_for <seconds> <command…>: poll until the command succeeds
  local deadline=$((SECONDS + $1))
  shift
  until "$@"; do
    if [ $SECONDS -ge $deadline ]; then return 1; fi
    sleep 0.2
  done
}

running() { pgrep -x FilenameChanger >/dev/null; }
not_running() { ! running; }
has_window() { ax window >/dev/null 2>&1; }
on_screen() { [[ "$(ax window 2>/dev/null)" == *" onscreen" ]]; }
field_reads() { [ "$(ax value "$1")" = "$2" ]; }

# Lets the app catch up with what was just done, then prints its state.
settle() {
  sleep "${1:-0.5}"
  cmd_state
}

# Keystrokes and menu clicks go to whichever app is frontmost, so the window
# must be in front and on this Space first.
bring_forward() {
  osascript -e "tell application id \"$BUNDLE_ID\" to activate"
  wait_for 3 on_screen || { echo "The window isn't on screen (another Space?)." >&2; exit 1; }
}

cmd_build() { # build: bundle FilenameChanger.app, signed ad hoc
  CODESIGN_IDENTITY=- ./bundle.sh 2>/dev/null | tail -1
}

cmd_fixture() { # fixture: a fresh folder of throwaway files to rename; prints its path
  local dir="$RUN_DIR/files"
  rm -rf "$dir"
  mkdir -p "$dir"
  touch "$dir/IMG_0001.JPG" "$dir/IMG_0002.JPG" "$dir/holiday notes.txt" "$dir/Report FINAL v2.pdf"
  echo "$dir"
}

# Presets and history go to $RUN_DIR/store, never the user's own in Application
# Support: every trial rename would otherwise land in their History.
cmd_launch() { # launch [folder]: quit any copy, open the app with the folder's files, wait for its window
  [ -d "$APP" ] || { echo "No FilenameChanger.app; run: driver.sh build" >&2; exit 1; }
  if running; then cmd_quit >/dev/null; fi
  local env=(--env "FILENAMECHANGER_STORE=$RUN_DIR/store")
  [ $# -gt 0 ] && env+=(--env "FILENAMECHANGER_FOLDER=$(cd "$1" && pwd)")
  open "${env[@]}" "$APP"
  wait_for 15 has_window || { echo "FilenameChanger launched but showed no window" >&2; exit 1; }
  settle
}

cmd_state() { # state: the sheet if one is up, else each pop-up, field and row, and the count
  if running; then ax state; else echo "not running"; fi
}

cmd_tree() { # tree: every accessibility element in the window or sheet, with labels and values
  ax tree
}

cmd_pick() { # pick <pop-up> <item>: choose from a pop-up, given by label, number or current value
  ax pick "$1" "$2"
  settle
}

cmd_press() { # press <control>: press a button, checkbox or tab, given by label or number
  ax press "$1"
  settle 1
}

cmd_type() { # type <field> <text>: replace a text field's contents, the field given by label or number
  bring_forward
  ax focus "$1"
  # Checked again in the same script, so the keys can't land in the terminal if
  # focus has moved since bring_forward.
  osascript - "$BUNDLE_ID" "$2" <<'EOF'
on run argv
  tell application "System Events"
    set frontID to bundle identifier of (first process whose frontmost is true)
    if frontID is not (item 1 of argv) then
      error "FilenameChanger isn't frontmost; not typing."
    end if
    keystroke "a" using command down
    keystroke (item 2 of argv)
  end tell
end run
EOF
  if ! wait_for 2 field_reads "$1" "$2"; then
    echo "Field $1 reads \"$(ax value "$1")\", not \"$2\": the keys went elsewhere. Run it again." >&2
    exit 1
  fi
  settle 0.2
}

cmd_menu() { # menu <menu> <item>: click a menu item, e.g. menu Edit Undo
  bring_forward
  osascript - "$BUNDLE_ID" "$1" "$2" <<'EOF' >/dev/null
on run argv
  tell application "System Events" to tell (first process whose bundle identifier is (item 1 of argv))
    click menu item (item 3 of argv) of menu (item 2 of argv) of menu bar item (item 2 of argv) of menu bar 1
  end tell
end run
EOF
  settle 1
}

cmd_ss() { # ss [name]: screenshot the window to $RUN_DIR/<name>.png, on screen or not
  local name="${1:-screen}" id
  mkdir -p "$RUN_DIR"
  id=$(ax window | cut -d' ' -f1)
  screencapture -x -o -l"$id" "$RUN_DIR/$name.png"
  sips -Z 1400 "$RUN_DIR/$name.png" >/dev/null
  echo "$RUN_DIR/$name.png"
}

cmd_files() { # files [folder]: list the folder on disk, the fixture by default
  ls -1 "${1:-$RUN_DIR/files}"
}

cmd_quit() { # quit: quit the app and wait until it has gone
  running || { echo "not running"; return; }
  osascript -e "tell application id \"$BUNDLE_ID\" to quit"
  wait_for 10 not_running || { echo "Still running after quit" >&2; exit 1; }
  echo "quit"
}

cmd_help() {
  sed -n 's/^cmd_[a-z_]*() { # //p' "$0"
}

command="${1:-help}"
shift || true
if declare -F "cmd_$command" >/dev/null; then
  "cmd_$command" "$@"
else
  echo "Unknown command: $command" >&2
  cmd_help >&2
  exit 1
fi
