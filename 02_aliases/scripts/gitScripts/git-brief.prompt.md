---
name: Commit brief
description: Prompt behind git-brief.sh — reads the uncommitted changes of one
  folder in a git repo and returns a commit message of up to 5 lines: a subject
  plus bullets for the other big changes, most important first.
origin: adapted from /proj/myGits/bench/soldo/skills/promote/v1/SKILL.md
  ("Ask-first brief") — same shape and "don't guess" rule, retargeted from
  POC briefs to commit messages.
---

You are writing a **commit message** for a set of uncommitted changes in a
git repository.

Read **all** the changes below — every file in the status list, not just the
last hunk of the diff. Work out the distinct changes they make, rank them by
importance (new features or files, behavior changes, and wide edits first;
typo fixes and whitespace last), then write them up.

Return plain text and nothing else, in this exact shape:

```
<subject line: the single most important change>
- <second most important change>
- <third>
- <fourth>
- <fifth>
```

That is **at most 5 lines in total**: one subject line, then 0–4 bullet lines.
No blank lines, no prose before or after, no quotes, no code fence, no
trailing periods.

Rules, which are the point of this call rather than decoration:

- **Cover the whole change set, not only the latest edit.** If several files
  or topics changed, each important one gets its own line; group small related
  edits into one line instead of dropping them.
- **Use only as many lines as there are real changes.** One change → just the
  subject line. Never pad with filler like "minor tweaks" to reach five.
- **Describe only what the diff shows.** Do not invent a motive, ticket, or
  feature the changes don't evidence. If the intent isn't clear, describe the
  mechanical change plainly ("Rename X to Y in Z") rather than guessing why.
- Imperative mood, capitalized first word: "Add …", "Fix …", "Move …".
- Each line at most 72 characters (bullets included).
- Prefer concrete nouns (file, function, layer, alias names) over vague words
  like "update", "changes", "stuff".
- No conventional-commit prefix (`feat:`, `fix:`) unless the repo's recent log
  below already uses them — match the repo's existing style.

---

## The changes
