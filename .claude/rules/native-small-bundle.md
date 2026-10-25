---
title: Small, With No Dependencies
impact: MEDIUM
impactDescription: The app is about 750 KB on disk; growth is a signal
tags: [native, macos, bundle, dependencies, size]
paths: ["Package.swift", "bundle.sh", "scripts/**", "icon/**"]
---

## Small, With No Dependencies

**Impact: MEDIUM**

`FilenameChanger.app` is 716 KB on disk (`du -sh`): the executable 634 KB
(649,472 bytes) and the icon 69 KB (70,997 bytes, repacked). That is the
stripped `-Osize` release build of 25 October 2026, Developer ID signed. `Package.swift` has no
dependencies. The rename engine, the move sequencing, the wildcard translation
and the persistence are this package's own code over Foundation, ImageIO,
AppKit, SwiftUI and Quick Look, all already on every Mac. `bundle.sh` builds
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
