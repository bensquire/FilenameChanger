---
title: Never Commit or Push Unless Told To
impact: CRITICAL
impactDescription: A committed feature the user did not want costs a revert and trust
tags: [workflow, git, commits, handover]
---

## Never Commit or Push Unless Told To

**Impact: CRITICAL**

Do not commit, and do not push, unless the user has said to in this
conversation. "Make it work", "fix it" and "finish it" are not that instruction.
"Commit", "commit and push", or a reply that says the work stays, are. When
told to commit on `main`, branch first and say so. Pushing a `v*` tag cuts a
public release, so a tag is never pushed without being asked for by name.

The user tries a feature before deciding whether it stays. A working feature is
not the same as a wanted one, and only they can tell the difference.

This is about product decisions, not about editing: do not ask permission to
change files. If the working copy is not a git repository, do not create one.

**Incorrect (committing because the work is done):**

```
Tests pass and the swap renames cleanly, so I've committed and pushed.
```

**Correct (handing over and waiting):**

```
Tests pass. I've rebuilt and relaunched the app — try the swap on the copy in
~/Desktop/swap-test. Nothing is committed; say if it stays.
```
