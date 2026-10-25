---
title: Commit Messages Are Prose With the Measurements
impact: HIGH
impactDescription: The history is where the reasoning is kept
tags: [workflow, git, commits, history]
---

## Commit Messages Are Prose With the Measurements

**Impact: HIGH**

When told to commit, the message says what changed and why, in prose, with the
measurements that justified it — the folder or fixture, the figure before, the
figure after — and what was tried and taken out, if anything was. One commit
per change of meaning: work that was already in the tree and is not part of the
change goes in its own commit, described honestly. End with the attribution
lines the session prescribes.

**Incorrect:**

```
Fix renames and cleanup
```

**Correct:**

```
Route chained renames through a temporary name

Renumbering 1, 2, 3 to 2, 3, 4 flagged two rows as taken, because each
target was a file still waiting to move. The engine now counts a target
as free when the batch itself moves its occupant, and RenameSequencer
orders the moves tail-first. A swap or rotation parks one file under a
hidden name in the same folder. Tested on disk: a shift and a swap keep
every file's bytes, and no temporary file is left.
```
