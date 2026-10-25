---
title: A Failure Reads as a Sentence
impact: MEDIUM
impactDescription: A bare check fails as "false" with no story
tags: [testing, assertions, messages, swift-testing]
paths: ["Tests/**/*.swift"]
---

## A Failure Reads as a Sentence

**Impact: MEDIUM**

The sentence starts with the test's display name, `@Test("a collision never
overwrites the existing file's contents")`, which the report prints. Swift
Testing's `#expect` then shows the expression and the values on each side, so
`#expect(sandbox.contents(of: "report.txt") == "PRECIOUS")` already says what
was found. A parameterised test's report names the argument that failed.

Add a comment, the second argument to `#expect`, where the expression alone
does not tell the story: a bare Boolean, or a check whose reason is not
obvious. Split two checks joined by `&&` into two `#expect`s, so a failure
names the half that failed. Use `try #require` for the thing the rest of the
test cannot run without, with a comment saying what was missing. A helper that
expects on the caller's behalf takes `sourceLocation: SourceLocation =
#_sourceLocation` and passes it on, so the failure lands on the test, not the
helper. No helper does that today; the shared helpers in
`FakeMetadataProvider.swift` return values and leave the checking to the test.

**Incorrect:**

```swift
#expect(model.history.isEmpty)                                    // why should it be?
#expect(sandbox.exists("x-a.txt") && !sandbox.exists("a.txt"))   // which half failed?
```

**Correct:**

```swift
#expect(model.history.isEmpty, "a failed batch isn't recorded as history")
#expect(sandbox.exists("x-a.txt"))
#expect(!sandbox.exists("a.txt"))
let row = try #require(plan.first, "the plan has no row for photo.jpg")
```

Reference: `/documentation/testing/expect(_:_:sourcelocation:)`.
