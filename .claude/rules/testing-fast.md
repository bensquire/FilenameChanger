---
title: Fast, but Not Over Accuracy
impact: MEDIUM
impactDescription: A test that is quick because it cannot see the defect is not a test; a slow suite is one nobody runs
tags: [testing, performance, accuracy, fixtures, disk]
paths: ["Tests/**/*.swift"]
---

## Fast, but Not Over Accuracy

**Impact: MEDIUM**

A test is first for what it proves, then as cheap as that allows — never the
other way round. The suite is fast: 103 tests in 12 suites ran in 0.07 s on 25
October 2026, and `make test` took 1.5 to 1.9 s wall clock with the build warm
(about 21 s from clean, most of it compiling). It is a debug build; nothing in
it needs optimising. Speed is bought by not paying for what the test does not
need. The function and engine tests never touch the disk: `FakeMetadataProvider`
says which names exist and what dates a file has. Only the suites about the
disk create files (`RenameOnDiskTests`, `FileAdderTests`, `PersistenceTests`,
`AppDelegateTests`), and those files are empty or hold a few bytes.

Speed is never bought by making the test see less. A test of a rename on disk
uses the real `SystemFileMetadataProvider` and the real
`FileManager.moveItem`, because only the real volume shows what matters: that
a case-only rename on a case-insensitive volume works, that a move never
overwrites, that a swap leaves no temporary file behind. Those files hold
distinctive bytes, so the test proves the content moved with the name. A fake
that moves nothing, or a check of names alone, is a faster test that no longer
tests. A new test much slower than the rest (a tenth of a second, say) says
why in its Arrange note.

**Incorrect (fast because it cannot see):**

```swift
let model = AppModel(provider: FakeMetadataProvider(), store: store) { _, _ in }   // moves nothing
model.performRename(undoManager: nil)
#expect(model.items.map(\.originalName) == ["1.txt", "2.txt"])   // names only, on no disk
```

**Correct (cheap where it costs nothing to be; real where it counts):**

```swift
let sandbox = try Sandbox(["2.txt", "1.txt"])   // two real files, a few bytes each
sandbox.write("TWO", to: "2.txt")
sandbox.write("ONE", to: "1.txt")
let model = makeModel(in: sandbox.directory)    // real provider, real moveItem
```
