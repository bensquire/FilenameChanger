---
title: Every Test Arranges, Acts and Asserts
impact: HIGH
impactDescription: A test with a step missing tests something other than it claims
tags: [testing, aaa, structure, swift-testing]
paths: ["Tests/**/*.swift"]
---

## Every Test Arranges, Acts and Asserts

**Impact: HIGH**

Every test has three steps, in this order, each present and identifiable. A
test longer than a few lines marks them `// Arrange`, `// Act`, `// Assert`, as
`failedRollbackIsReported` and `diskCollisionFlagged` do; a new test does too.

1. **Arrange**: build the input. That might be file items from `items(_:)`, a
   `FakeMetadataProvider` that says which names exist, a `Sandbox` of real
   files, or a model from `makeModel`. A short note after the marker says what
   is special about it (`// Arrange: the target "report.txt" already exists on
   disk.`).
2. **Act**: the one call under test, usually `RenameEngine.plan`,
   `RenameSequencer.ordered` or `model.performRename`. One act per test where
   the design allows. A test that acts twice is two tests, or a test of the
   pair, marked `// Act / Assert`. A rename followed by its undo is such a
   pair.
3. **Assert**: `#expect` against what the act produced; `try #require` for the
   thing the rest cannot run without.

The steps need not be on separate lines (a short test can be one line), but a
reader should be able to point at the input, the call, and the check.

**Incorrect (the act hidden inside the assert; no arrange at all):**

```swift
#expect(RenameEngine.plan(items: items(["draft.txt"]), function: .replaceFirst(find: "draft", with: "report"), options: RenameOptions(), provider: FakeMetadataProvider(existingNames: ["report.txt"])).first?.issue == .collision)

@Test func flagsCollision() { #expect(plan.first?.issue == .collision) }   // plan built where?
```

**Correct:**

```swift
// Arrange: the target "report.txt" already exists on disk.
let provider = FakeMetadataProvider(existingNames: ["report.txt"])
// Act
let plan = RenameEngine.plan(
    items: items(["draft.txt"]), function: .replaceFirst(find: "draft", with: "report"),
    options: RenameOptions(), provider: provider)
// Assert
#expect(plan.first?.issue == .collision)
#expect(plan.first?.willRename == false)
```
