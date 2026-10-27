---
title: FilenameChanger Rules Index
impact: LOW
impactDescription: About the rules themselves; loads only when a rule is being written
tags: [meta, rules]
paths: [".claude/rules/*.md"]
---

# FilenameChanger Rules

Modular, machine-readable rules for working on FilenameChanger. Each file is
one rule, named `{section}-{rule-name}.md`, with YAML frontmatter Claude Code
reads: a rule with `paths` loads only when a matching file is in play; one
without applies always. `_sections.md` defines the sections and their order;
`_template.md` is the shape of a new rule.

## Rules Index

### Workflow

- [workflow-challenge-the-rules](workflow-challenge-the-rules.md) - A rule in the way is raised with the user, not obeyed or broken in silence
- [workflow-no-commits-unless-told](workflow-no-commits-unless-told.md) - Never commit, push or tag unless told to
- [workflow-hand-over-for-trial](workflow-hand-over-for-trial.md) - Bundle, relaunch, say what state and what to look at, stop
- [workflow-checking-work](workflow-checking-work.md) - Lint, the whole suite, then real files renamed and undone in a throwaway folder
- [workflow-commit-messages](workflow-commit-messages.md) - Prose, with the measurements
- [workflow-diagnostics](workflow-diagnostics.md) - `FILENAMECHANGER_*` read at the composition root to keep, a separate file to throw away

### Quality

- [quality-separation-of-concerns](quality-separation-of-concerns.md) - RenameKit knows no window and moves no files; dependencies run one way
- [quality-dependency-injection](quality-dependency-injection.md) - Provider, store, move and temporary names handed in as values
- [quality-readability](quality-readability.md) - Code reads like the prose around it
- [quality-consistency](quality-consistency.md) - Match the code around you; reuse the helper that exists
- [quality-extensible](quality-extensible.md) - A new function is a case and its arm, found by the exhaustive `switch`
- [quality-performant](quality-performant.md) - The plan reruns per keystroke: metadata only when used, caches, one plan a render, measured
- [quality-secure](quality-secure.md) - Offline; nothing overwritten; a failed batch rolled back; settings kept as `.bak`
- [quality-comments-carry-measurements](quality-comments-carry-measurements.md) - Short, says why, carries the number or the doc path
- [quality-formatting-is-the-tools](quality-formatting-is-the-tools.md) - Apple's swift-format decides, strict
- [quality-images-minified](quality-images-minified.md) - Lossless first, then lossy to the edge; the icon repacked, not re-encoded

### Testing

- [testing-arrange-act-assert](testing-arrange-act-assert.md) - Each step present, in order, marked
- [testing-one-behaviour-per-test](testing-one-behaviour-per-test.md) - One behaviour, its `@Test` name a sentence; `arguments:` for a table
- [testing-ground-truth-with-teeth](testing-ground-truth-with-teeth.md) - Judge the files on disk, contents included; say what the alternative measures
- [testing-deterministic](testing-deterministic.md) - Files made in code, own temp folders and stores; fixed dates; safe in parallel
- [testing-fast](testing-fast.md) - Fast by keeping the engine off the disk, never by faking the disk a rename test needs
- [testing-failure-reads-as-a-sentence](testing-failure-reads-as-a-sentence.md) - A comment where the expression alone doesn't tell the story

### Native

- [native-use-the-systems-feature](native-use-the-systems-feature.md) - Open panel, Finder Service, Open With, Quick Look, UndoManager, SF Symbols, confirmationDialog
- [native-keyboard-and-menus](native-keyboard-and-menus.md) - The shortcuts every Mac user knows; every action in the File menu
- [native-small-bundle](native-small-bundle.md) - 972 KB, no dependencies
- [native-check-apples-documentation](native-check-apples-documentation.md) - Look it up in `scrapple` before using, copying or asserting

### Communication

- [communication-plain-language](communication-plain-language.md) - ISO 24495-1: relevant, findable, understandable, usable
