---
title: Hand Work Over for the User to Try
impact: CRITICAL
impactDescription: The user judges a feature in the app, not in a report
tags: [workflow, handover, bundle, app]
---

## Hand Work Over for the User to Try

**Impact: CRITICAL**

When a change the user can see in the app is done and checked, put it in front
of them there. A change to the tests, the rules or the docs is handed over as
what it is: the suite's result, the file to read.

1. `make bundle`, so `FilenameChanger.app` carries the change. It signs with
   the Developer ID in the keychain; `CODESIGN_IDENTITY=- ./bundle.sh` signs ad
   hoc, as CI's smoke build does, where that identity is not available.
2. Relaunch it: `pkill -x FilenameChanger; open FilenameChanger.app`. Quit
   first: `open` brings forward a FilenameChanger that is already running —
   another copy, such as one in `/Applications`, has the same bundle
   identifier (`com.bensquire.filenamechanger`) — instead of starting this one.
   `open --env FILENAMECHANGER_FOLDER=/path FilenameChanger.app` starts it with
   a folder's files loaded.
3. Say what state the trial assumes. The file list, the chosen function and the
   options start fresh at every launch. Presets and history persist, as
   `presets.json` and `history.json` in
   `~/Library/Application Support/FilenameChanger/`.
4. For a change to the Finder Service, say that Finder may need
   `/System/Library/CoreServices/pbs -update` before the menu item changes.
5. Say what to look at, on which throwaway folder, and what the figures were.
6. Stop.

**Incorrect (declaring done from the command line):**

```
The suite passes and the swap test keeps both files' bytes. Done.
```

**Correct (the app relaunched, the eye pointed):**

```
Rebuilt and relaunched. Add the copy in ~/Desktop/swap-test, drag 2.txt above
1.txt, choose Sequence (1 digit, from 1, replacing the name) and press ⌘↩:
the two files trade names, each keeping its contents, and ⌘Z puts them back.
Nothing else in the folder changes.
```
