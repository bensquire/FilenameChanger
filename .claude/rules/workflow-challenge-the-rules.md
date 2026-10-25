---
title: Challenge a Rule When It Is in the Way
impact: CRITICAL
impactDescription: The rules serve the best system; a rule that blocks a better one is a defect to raise, not a wall to work around
tags: [workflow, rules, architecture, standards, judgement]
---

## Challenge a Rule When It Is in the Way

**Impact: CRITICAL**

These rules exist to make the best system, not to be obeyed for their own
sake. When following one would make the code, the architecture, a standard
or the product worse — or when a better way exists that a rule forbids —
raise it with the user, plainly: which rule, what it costs here, what the
alternative is, and what it would take. Then wait. Sometimes the answer is to
rearchitect, change a standard, or rewrite the rule.

Silent compliance and silent breaking both hide the decision, so do neither.
A rule the user has just confirmed stands.

**Incorrect (working under it in silence):**

```
Tests should give the same answer on every machine, so I've tested the
case-only rename against FakeMetadataProvider instead of real files.
```

**Correct (the case made, the decision left with the user):**

```
"Every run gives the same answer" and "ground truth is the files on disk" pull
apart here: a case-only rename (photo → PHOTO) only shows its bug on a
case-insensitive volume, and a temp folder on a case-sensitive one would see
a different result. I'd keep the on-disk test and skip it, with the reason,
where the temp folder is case-sensitive. Want that, or a different split?
```
