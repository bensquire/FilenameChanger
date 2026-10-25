---
title: The Shortcuts and Menus Every Mac User Knows
impact: HIGH
impactDescription: An invented shortcut is one the user has to learn; a missing menu item is one they cannot find
tags: [native, macos, keyboard, shortcuts, menus]
paths: ["Sources/RenameApp/**/*.swift", "Sources/FilenameChanger/**/*.swift"]
---

## The Shortcuts and Menus Every Mac User Knows

**Impact: HIGH**

Every action the user can take from a button can be taken from the menu bar,
and the common ones carry the platform's shortcut:

| Action | Shortcut |
|---|---|
| Add Files… | ⌘O |
| Rename | ⌘↩ |
| Quick Look the selected file | Space, while the file list has focus |
| Undo, redo a batch | ⌘Z, ⇧⌘Z |
| Confirm, cancel | Return, Escape |
| Close, minimise, hide, quit | ⌘W, ⌘M, ⌘H, ⌘Q — never overridden |

A new action takes the shortcut the platform's guidelines give it, or none. A
shortcut is never invented where Apple has assigned one, and never reused for a
second meaning. A plain key such as Space is handled with `onKeyPress` on the
table, so it acts only while the file list has focus. A window-wide
`keyboardShortcut` would swallow spaces typed into a parameter field.

Menus are the standard set in the standard order (App, File, Edit, View,
Window, Help), with the app's items placed in the group they belong to. The
File menu (`FileCommands`) holds the Add items, Rename, Save Current Rename…,
the Presets and History…, so every toolbar and bottom-bar action is in the
menu bar too. Undo and Redo are the Edit menu's own, driven by the window's
`UndoManager`; they are not rebuilt. A menu command that needs the window's
state (its undo manager, its sheets) reaches it through `focusedSceneValue`
(`WindowActions`), not through a global.

**Incorrect (a new top-level menu for one item; a shortcut with a meaning of its own):**

```swift
CommandMenu("Rename") { Button("Rename Now") { … }.keyboardShortcut("r") }
```

**Correct:**

```swift
CommandGroup(after: .newItem) {
    Button("Rename") { actions?.rename() }
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(actions?.canRename != true)
}
```

Reference: Apple Human Interface Guidelines, Keyboard and Menus.
