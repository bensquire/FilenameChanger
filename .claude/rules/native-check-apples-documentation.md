---
title: Check Apple's Documentation Before Using Its API
impact: HIGH
impactDescription: A guessed signature compiles by luck; a copied feature is one the OS already had
tags: [native, documentation, scrapple, apple, hig, wwdc]
paths: ["Sources/**/*.swift"]
---

## Check Apple's Documentation Before Using Its API

**Impact: HIGH**

Before using a system API you are not certain of, before building anything the
system might already provide, and before stating a platform convention as fact,
look it up. `scrapple` holds Apple's framework documentation, WWDC transcripts
and sample code offline. It does not hold the Human Interface Guidelines; their
conventions are in the design talks. The `apple-docs` skill says how to ask it.
A symbol name is the best query. A decision that rests on what a page says
carries the page's path in a one-line comment, as the code already does
(`/documentation/appkit/nsapplicationdelegate/application(_:open:)`,
`/documentation/appkit/nsapplication/servicesprovider`), so the next reader can
check it too. A doc that contradicts a deliberate design choice is raised with
the user, not followed or ignored in silence. One such choice: `TextMatching`
uses `NSRegularExpression`, not Swift's `Regex`, because it needs `$1`
templates and first-match replacement, and its comment says so.

This matters most around `FileManager`'s moves and directory walks,
`NSRegularExpression`'s templates, ImageIO's EXIF keys, the Services API, and
SwiftUI's newer modifiers (`Table`, `quickLookPreview`, `focusedSceneValue`).

**Incorrect (guessed: does a move replace what is already there?):**

```swift
// Clear the way, in case moveItem refuses an existing file.
try? FileManager.default.removeItem(at: to)   // and if `to` was the user's file?
try FileManager.default.moveItem(at: from, to: to)
```

**Correct (looked up, and named):**

```sh
scrapple search "FileManager moveItem" --type doc --limit 3 --human --keyword-only
```

```swift
// /documentation/foundation/filemanager/moveitem(at:to:): "If an item with the
// same name already exists at dstURL, this method stops the move attempt".
try FileManager.default.moveItem(at: from, to: to)
```

Reference: `scrapple` (github.com/searlsco/scrapple); Apple Developer Documentation.
