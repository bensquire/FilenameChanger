---
title: Every Run Gives the Same Answer
impact: HIGH
impactDescription: A flaky test is a test nobody trusts
tags: [testing, determinism, fixtures, clock, parallel]
paths: ["Tests/**/*.swift"]
---

## Every Run Gives the Same Answer

**Impact: HIGH**

Fixtures are made in code, never fetched or committed. An engine test never
touches the disk: its file items point under `/tmp/fnc-test`, which is never
created, and `FakeMetadataProvider` answers which names exist and what dates a
file has. A test that does touch the disk makes its own folder of real files
(`Sandbox`, `TempDir`), named with a UUID and removed when the test ends. No
network.

No wall-clock dependence. A date is a fixed instant (`DateTests.fixedDate`),
never `Date()`. Sequence's date sort breaks ties on the name, so files with the
same date number the same way every run. `RenameSequencerTests` injects its
temporary names, so the expected moves are stable. `DateStamp` formats in the
local time zone, so the fixed date is built in that zone too — noon local — and
reads as the same day wherever the suite runs. A fixed UTC instant doesn't:
noon UTC is the 16th in UTC+14. Check with `TZ=Pacific/Kiritimati swift test`.

No dependence on another test or on order. Swift Testing runs tests in
parallel, so no two tests share a folder, a store or a pasteboard. Each model
gets a `PersistenceStore` in its own temp directory, so a test never reads or
writes the user's presets and history in Application Support. A Service test
uses `NSPasteboard.withUniqueName()`. A failure is injected, as the `moveItem`
that throws on its second call is, rather than arranged through file
permissions.

**Incorrect:**

```swift
let config = DateConfig(source: .custom(Date()))   // a different stamp tomorrow
let model = AppModel()                              // the user's real presets and history
```

**Correct:**

```swift
let config = DateConfig(source: .custom(fixedDate), format: .preset(.isoDash))
let store = PersistenceStore(
    directory: directory.appendingPathComponent("store-\(UUID().uuidString)"))
let model = AppModel(store: store)
```
