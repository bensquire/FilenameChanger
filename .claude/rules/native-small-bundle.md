---
title: Small, With No Dependencies
impact: MEDIUM
impactDescription: The app is about 750 KB on disk; growth is a signal
tags: [native, macos, bundle, dependencies, size]
paths: ["Package.swift", "bundle.sh", "scripts/**", "icon/**"]
---

## Small, With No Dependencies

**Impact: MEDIUM**

`FilenameChanger.app` is 848 KB on disk (`du -sh`): the executable 768 KB
(782,208 bytes) and the icon 69 KB (70,997 bytes, repacked). That is the
stripped `-Osize` release build of 25 October 2026 with Smart Name, Developer ID
signed. Before Smart Name it was 716 KB, with a 634 KB executable. `Package.swift` has no
dependencies. The rename engine, the move sequencing, the wildcard translation,
the persistence and Smart Name's reader are this package's own code over
Foundation, ImageIO, AppKit, SwiftUI, Quick Look, PDFKit, Vision and Foundation
Models, all already on every Mac. `bundle.sh` builds
with `-Osize` and strips the executable.

That is a consequence of using the system's features and a check on it: a
feature that arrives with a package, a framework or a second executable is a
sign the wrong path was taken. Check `du -sh FilenameChanger.app` after
`make bundle`; growth needs a reason.

**Incorrect:**

```swift
// Package.swift
dependencies: [.package(url: "https://github.com/…/SwiftExif", from: "1.0.0")]   // for what ImageIO reads
```

**Correct:**

```swift
import ImageIO   // CGImageSourceCopyPropertiesAtIndex, kCGImagePropertyExifDateTimeOriginal
```
