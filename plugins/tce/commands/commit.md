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
If a ticket was finished, update its state in the ticket file (mark as done).

## Commit Message Format

Use conventional commits. If the chat is about a ticket, include the ticket ID:

```
<keyword>(<ticket-id>): <description>

<optional body explaining what was done and why certain decisions were made>
```

**Keywords:** feat, fix, refactor, docs, test, chore, style, perf, ci, build

**Rules:**
- Explain "what" was done, not "how" (the code shows how)
- Include "why" for non-obvious decisions (if not already in ticket)
- Keep first line under 72 characters

## Important

- **NEVER run `git push`** - the human decides when to push
- Commit TODO.md together with other artifacts if it was updated
- Commit ticket state changes in the same commit as the implementation
