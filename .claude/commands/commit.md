# Commit Changes

Commit all changes from the current chat session to Git.

## Pre-Commit Checklist

Before committing, verify each item:

### a) Determine commit type
Check if the commit contains only documentation changes (`.md` files):
- **Docs-only commit**: Skip steps b) and c) - no tests or typechecks needed
- **Code commit**: Run steps b) and c) before committing

### b) All tests pass (code commits only)
Run both frontend and backend tests:
```bash
cd [project-root]/backend && php artisan test
cd [project-root]/frontend && bun run test
```

> **Note:** Update these commands to match your project's test runners.

### c) Typecheck passes (code commits only)
Run frontend typecheck:
```bash
cd [project-root]/frontend && bun run typecheck
```

**Note:** Typecheck should be run frequently during development, not just at commit time. Type errors are easier to fix when caught early.

### d) Code style passes (code commits only)
Run linters to check and fix code style:
```bash
cd [project-root]/backend && ./vendor/bin/pint
cd [project-root]/backoffice && ./vendor/bin/pint
```

> **Note:** Update these commands to match your project's linters.

**Note:** Linters will automatically fix style issues. Review the changes they make before staging.

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
