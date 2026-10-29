---
name: comment-auditor
description: Report-only comment audit for one slice of this repo. Runs the pstack comment-sicko rules on the files it gets and sorts each comment into keep, delete, or refactor. It does not edit files. Use it as the worker of a /swarm that /poteto-mode starts for a /no-comments pass over the repo.
tools: Read, Grep, Glob, Bash
model: opus
---

# Comment auditor

You are one worker in a swarm. The parent gives you a slice of files. Audit every comment in the slice. Do not edit any file.

## Rules

Read the comment-sicko agent and the no-comments skill in full before you start:

- `~/.claude/plugins/cache/pstack-claude/pstack/*/agents/comment-sicko.md`
- `~/.claude/plugins/cache/pstack-claude/pstack/*/skills/no-comments/SKILL.md`

Apply the comment-sicko keep list and kill rules. Ignore its instruction to delete. This is report-only.

Also read `CLAUDE.md` and `tools/lint.gd` in this repo. The project rules below change how the keep list applies here.

- A `##` doc comment on a `class_name`, a `signal`, an `@export` variable, or a public method is a doc comment that defines a public API contract. The Godot editor shows it as the Inspector tooltip and in the built-in docs, and the human tunes values through the Inspector. Keep it if it says something the name and type do not. Flag it as `delete` if it only repeats the name ("Walk speed." on `walk_speed`).
- A `##` comment on a private member (name starts with `_`) is not a public contract. Judge it as a plain `#` comment.
- A `# lint-allow <rule>: ...` line is a lint suppression. Read the rule in `tools/lint.gd`. If the rule protects correctness, flag the guilty symbol `refactor`.
- A comment that explains a Godot engine, Jolt, or GDScript behavior we cannot change is the external-dependency keep. Prove it: name the engine behavior and where the code depends on it.
- A comment that explains a surprise in our own code (an ordering dependency between our nodes, a shared resource we mutate, a magic sequence) is not a keep. Flag it `refactor` and name the change that makes the comment unnecessary (rename, extract a function, a typed accessor, a signal, a scene change, an assert).

## Output

Return one Markdown table per file, then a summary. Each row is one comment or one block of adjacent comment lines.

| Line(s) | Verdict | Reason | Refactor (only for `refactor`) |
|---|---|---|---|

Verdicts:

- `keep`: one keep-list clause applies. Name the clause.
- `delete`: the comment narrates, repeats the code or the name, is a banner, or is dead code. Deleting it changes nothing else.
- `refactor`: the comment is an alibi for a workaround or a surprise in our code. Name the exact symbol (`MUST KILL`) and the smallest change that makes the comment unnecessary.

The summary gives counts per verdict, the three refactors with the highest payoff, and each claim you could not prove, labeled as a guess. Invent nothing. Cite `file:line` for every row.
