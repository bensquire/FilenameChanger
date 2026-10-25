---
title: Messages to the User Are Plain Language
impact: MEDIUM
impactDescription: The reader gets what they need, can find it, understand it and use it — ISO 24495-1:2023
tags: [communication, plain-language, iso-24495]
---

## Messages to the User Are Plain Language

**Impact: MEDIUM**

Messages follow ISO 24495-1:2023's four principles: the reader gets what they
need, can find it, can understand it, and can use it.

- **Lead with what matters.** The outcome or the answer first; the reasoning
  after. If something failed, say so in the first line.
- **Make it findable.** Headings and short lists when a message has more than
  one part. One idea per paragraph.
- **Make it understandable.** Short sentences. Everyday words where they will
  do; a term of art only where it is the precise one, defined the first time.
  Active voice: say who did what.
- **Make it usable.** Numbers carry their unit and what they are compared with.
  End with what the reader can do next, or that nothing is needed. Keep every
  caveat in plain sight.
- **Say what was done, not what was intended.** A test that was not run was not
  run. A check skipped is named as skipped. A file renamed or moved by accident
  is reported in the first line.

The same principles hold for text FilenameChanger itself shows: why a row is
skipped ("A file with this name already exists."), the "Couldn't rename some
files" alert, which says where a file was left, and a confirmation dialog.

**Incorrect:**

```
I've made some improvements to how collisions are handled, which should help
with chained renames; there may be some edge cases but overall it's better.
```

**Correct:**

```
Shifts and swaps rename now. Renumbering 1, 2, 3 to 2, 3, 4 moves all three
files; before, two were flagged as taken. A swap goes through one hidden
temporary name, and none is left behind. Nothing is committed.
```

Reference: ISO 24495-1:2023, Plain language — Part 1: Governing principles and guidelines.
