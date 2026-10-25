---
title: Use the System's Feature, Not a Copy of It
impact: HIGH
impactDescription: The OS version already handles accessibility, Dark Mode, localisation and next year's macOS
tags: [native, macos, appkit, swiftui, quick-look, finder, services, undo]
paths: ["Sources/RenameApp/**/*.swift", "Sources/FilenameChanger/**/*.swift", "Sources/RenameKit/**/*.swift", "Sources/RenameIntelligence/**/*.swift", "scripts/Info.plist.template"]
---

## Use the System's Feature, Not a Copy of It

**Impact: HIGH**

FilenameChanger should feel like a Mac app Apple could have shipped: it behaves
the way the user's other apps behave, by using what macOS provides rather than
building a version of its own. Before writing a control, a panel, a preview or
an alert, ask whether the OS has one. It usually does.

- **Choosing files** is `NSOpenPanel` (`FileAdder.present`), plus drag and drop
  onto the window. Dropped folders are walked, hidden files skipped, and
  packages kept whole, without asking.
- **Arriving from Finder** is the system's: the "Rename with FilenameChanger"
  Service (`NSServices` in `Info.plist.template`, answered by
  `AppDelegate.renameFiles`), and Open With and drops on the Dock icon through
  `application(_:open:)`. The document type is `public.item` at rank `None`, so
  the app is offered in Open With without becoming the default for anything.
- **Looking at a file** is Quick Look (`quickLookPreview`, toggled with Space).
  Showing where a file is is `NSWorkspace.activateFileViewerSelecting`, and a
  row's icon is `NSWorkspace.icon(forFile:)`.
- **Undo** is the window's `UndoManager`: a batch registers its inverse moves
  and an action name, and the Edit menu's Undo and Redo do the rest.
- **Reading a photo's date** is ImageIO's EXIF dictionary; file dates are
  `URLResourceValues`.
- **Icons** are SF Symbols, chosen for their meaning. No bitmaps for things a
  symbol says.
- **Confirming a destructive step** is the system's `confirmationDialog`, as
  clearing the history is, and a failure is the system's `alert`. Not a sheet
  of our own.
- **Text, colour and spacing** are `Font` styles, semantic colours and standard
  control sizes. Nothing hard-coded that the system defines.

Native is not generic: the live plan, the collision rules, the move sequencing
and the highlighted change in the New Name column are the app's own work,
built from the system's parts. The table is SwiftUI's `Table`, with
`ContentUnavailableView` when it is empty.

**Incorrect (a preview of our own):**

```swift
struct FilePreview: View { … Image(nsImage: NSImage(contentsOf: url)) … }   // a sheet with arrows
```

**Correct (the system's):**

```swift
.quickLookPreview($previewItem, in: plan.map(\.url))
```
