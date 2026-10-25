---
title: Add a Case and Its Behaviour, Not an `if`
impact: HIGH
impactDescription: A special case on shared infrastructure is a band-aid the next change tears off
tags: [quality, extensibility, altitude, design]
paths: ["Sources/**/*.swift"]
---

## Add a Case and Its Behaviour, Not an `if`

**Impact: HIGH**

The places FilenameChanger grows are enumerations with one mechanism behind
them. `RenameFunction` says it in its own doc comment: "Adding a behaviour is a
new case and its arm in `proposedBaseName` — never a flag threaded through the
others." What the engine needs to know about a function is derived from the
case: `preservesExtension` (the word-splitting Change Case styles never touch
the extension) and `readsMetadata` (only a Date stamp from the file or its
EXIF). A `RenameIssue` is a case with its text in `issueText`. A `TextCase`, a
`DatePreset` and a `Placement` are cases the function switches on.

Adding a function means a `RenameFunction` case and its arm, a `FunctionKind`
case and its title, the model's fields with their arms in `function` and
`loadParameters(from:)`, and its controls in `FunctionParametersView`. Every
one of those is an exhaustive `switch`, so the compiler finds each place that
has to say something about the new case. No `if` in the engine for the new
one.

When a change wants a special case on shared code, the fix is usually one level
deeper: make the shared mechanism carry what the case needs. An emptied name is
one example. Any function could leave a bare `.jpg`, so the engine flags every
empty result as invalid in one place, not each function guarding its own.

**Incorrect (the engine learns about one case on the side):**

```swift
// in RenameEngine.plan
if case let .changeCase(style) = function, style == .snake || style == .kebab {
    hidesExtension = true   // and camel, pascal, screamingSnake are forgotten
}
```

**Correct (the case carries it, through the one mechanism):**

```swift
public var preservesExtension: Bool {
    if case let .changeCase(textCase) = self { return textCase.operatesOnWords }
    return false
}
// RenameEngine
let hidesExtension = options.hideExtension || function.preservesExtension
```
