---
description: Commit the current session's changes with pre-commit checks (tests/typecheck/lint from the project profile) and a commit message in the project's configured convention.
---

# Commit Changes

Commit all changes from the current chat session to Git.

## Project context

This command ships in the **tce** workflow plugin and is stack-agnostic. The
project's actual test, typecheck, and lint commands live in
`${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`.

**Before running the checks below, read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`**
and use the exact commands it lists (including the directories to run them in).
If that file is missing, tell the user to run `/tce:init`, and meanwhile fall
back to test/lint tooling you can detect in the repo (`package.json` scripts,
`composer.json`, `Makefile`, etc.).

## Pre-Commit Checklist

Before committing, verify each item:

### a) Determine commit type
Check if the commit contains only documentation changes (`.md` files):
- **Docs-only commit**: Skip steps b), c) and d) - no tests, typechecks or linting needed
- **Code commit**: Run steps b), c) and d) before committing

### b) All tests pass (code commits only)
Run the project's test command(s) from `profile.md` (there may be more than one,
e.g. separate backend and frontend suites). All must pass.

### c) Typecheck passes (code commits only)
Run the project's typecheck command(s) from `profile.md`, if it defines any.

**Note:** Typecheck should be run frequently during development, not just at commit time. Type errors are easier to fix when caught early.

### d) Code style passes (code commits only)
Run the project's lint/format command(s) from `profile.md`.

**Note:** Linters often auto-fix style issues. Review the changes they make before staging.

### e) Review staged files
Check `git status` and `git diff --staged` to ensure:
- No unintended files (temp files, `.env` changes, debug code)
- All intended changes are staged

### f) TODO items added
If any "add to TODO" or similar was mentioned in the chat, ensure the items are added to `TODO.md`.

### g) Ticket state updated
If a ticket was finished, handle its status per the "Status / completion" section
of `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md`: update it via the documented
mechanism if the policy allows tce to transition tickets (for tmt, edit the
`**Status:**` line in the ticket file), otherwise remind the user that the
transition is due.

## Commit Message Format

Read the **`## Commit convention`** section of
`${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` and format the message exactly as it
specifies — the convention there governs the subject shape and where the ticket ID
goes. If the chat is about a ticket, include its canonical ticket ID (as defined in
`.claude/tce/tickets.md`, e.g. `MYAPP-0042`, `GH-123`) in the place the convention
prescribes; omit it when the commit isn't about a ticket. Regardless of convention:

**Rules:**
- Explain "what" was done, not "how" (the code shows how)
- Include "why" for non-obvious decisions (if not already in ticket)
- Keep first line under 72 characters

**If `profile.md` has no `## Commit convention` section** (older config, or no
profile), default to **Conventional Commits**:

```
<keyword>(<ticket-id>): <description>

<optional body explaining what was done and why certain decisions were made>
```

**Keywords:** feat, fix, refactor, docs, test, chore, style, perf, ci, build

## Important

- **NEVER run `git push`** - the human decides when to push
- Commit TODO.md together with other artifacts if it was updated
- If the ticket system stores tickets as files in the repo (tmt), commit ticket
  state changes in the same commit as the implementation
