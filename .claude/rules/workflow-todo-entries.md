---
title: A TODO Entry Is Short
impact: MEDIUM
impactDescription: The TODO is a list to scan, not a place to keep reasoning
tags: [workflow, todo, planning]
paths: ["TODO.md"]
---

## A TODO Entry Is Short

**Impact: MEDIUM**

`TODO.md` at the root is the user's local list of what is left. `.gitignore`
keeps it out of commits. Each entry is one bullet: a bold name, then a
sentence or two saying what is left and what would settle it. Entries are
grouped under a heading that says what kind of thing they are, and a thing is
never listed twice.

The reasoning (what was measured, what went wrong, why it was taken out)
lives in the commit that did it and the code that carries it, not here. When
an entry is done, delete it.

**Incorrect:**

```
## Shortcuts

The Rename Files action reads the window's documents through a throwaway
DocumentAnalysis … (three paragraphs on the intent, the probe shortcuts and
why EnumerableEntityQuery was turned down)
```

**Correct:**

```
## Not verified end to end

- **Rename Files in a folder automation.** Nothing has run the action from a
  folder automation with new files arriving in the folder.
```
