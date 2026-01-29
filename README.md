# Claude Code Project Template

A Claude Code configuration template derived from a real Laravel/Nuxt monorepo project. Use this as a starting point for setting up Claude Code workflows in your own projects.

## What's Included

- **CLAUDE.md** - Project instructions template with valuable patterns
- **.claude/agents/** - Specialized research and analysis agents
- **.claude/commands/** - Workflow commands (tickets, plans, reviews, etc.)
- **.claude/settings.json** - Hooks and notifications configuration

## Quick Start

1. Clone this repository or copy the files to your project
2. Edit `CLAUDE.md` with your project details
3. **Configure your ticket prefix** in all `scripts/*.sh` files (change `TICKET_PREFIX="PROJ"`)
4. Replace `[PREFIX]-XXXX` placeholders in command files with your actual prefix
5. Replace `[project-root]/` paths with your actual paths
6. Customize tech stack examples (currently Laravel/Nuxt)

## Files to Customize

### Must Edit

| File | What to Change |
|------|----------------|
| `CLAUDE.md` | Your project's architecture, directory structure, and conventions |
| `scripts/*.sh` | Set `TICKET_PREFIX="PROJ"` to your project's prefix in ALL scripts |
| `.claude/commands/commit.md` | Your test commands (`php artisan test`, `bun run test`, etc.) |
| `.claude/commands/discuss.md` | Your tech stack list |

### Optional Customization

| File | What to Customize |
|------|-------------------|
| `.claude/agents/web-search-researcher.md` | Add your preferred documentation sources |
| `.claude/settings.json` | Add your own hooks (currently has ticket validation hooks) |
| `.claude/settings.local.json` | Your personal permission settings (not committed) |

## Ticket Format

This workflow stores tickets as markdown files in Git (in a `thoughts/` directory). This keeps requirements, plans, and research alongside your code.

The template uses `[PREFIX]-XXXX` as a placeholder. Choose a short prefix derived from your project name:

- `MYAPP-0001` for a project called "MyApp"
- `ORD-0001` for an order management system
- `DOC-0001` for a documentation platform

The format is `[PREFIX]-XXXX` where XXXX is a zero-padded number (0001, 0002, etc.).

**Note:** This is NOT for external ticket systems like Jira or GitHub Issues. Tickets here are markdown documents committed to your repository that capture requirements, research, and implementation plans.

## Development Workflow

This template supports a 4-step development workflow:

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `/create_ticket` | Capture business requirements (WHAT & WHY) |
| 2 | `/research_codebase` | Research codebase, find patterns & libraries |
| 3 | `/create_plan` | Clarify questions, create detailed implementation plan |
| 4 | `/implement_plan` | Execute implementation using all documents |

Additional commands:
- `/commit` - Commit changes with pre-commit checks
- `/review` - Code review (ticket-based or custom scope)
- `/discuss` - Technical discussion and exploration

## Tech Stack Examples

Examples throughout use Laravel/Nuxt patterns. Adapt to your stack:

| Example | Alternatives |
|---------|-------------|
| Laravel | Django, Rails, Express, FastAPI |
| Nuxt/Vue | Next/React, SvelteKit, Astro |
| PHP | Python, Ruby, Node.js, Go |
| Pest/PHPUnit | pytest, RSpec, Jest, Vitest |

## Directory Structure

The workflow expects a `thoughts/` directory for documentation:

```
thoughts/
├── shared/
│   ├── tickets/      # Ticket definitions ([PREFIX]-XXXX-name.md)
│   ├── research/     # Codebase research documents
│   ├── plans/        # Implementation plans
│   ├── reviews/      # Code review documents
│   └── discussions/  # Technical discussion documents
└── [username]/       # Personal notes (optional)
```

## Agents

Specialized agents for different research tasks:

| Agent | Purpose |
|-------|---------|
| `codebase-locator` | Find files and directories by topic |
| `codebase-analyzer` | Understand implementation details |
| `codebase-pattern-finder` | Find similar implementations to model after |
| `thoughts-locator` | Find documents in thoughts/ directory |
| `thoughts-analyzer` | Extract insights from thought documents |
| `web-search-researcher` | Research external documentation |

## Key Patterns from This Template

### Git Commit Discipline
- Commits after every verified logical step
- Never amend existing commits
- Never auto-push (human decides when to push)

### Implementation Phase Discipline
- Tests are part of every phase, not a separate phase
- A phase is complete when all tests pass
- Commit after each phase passes verification

### Working Directory Discipline
- Always use absolute paths when switching directories
- Never run frontend commands from backend directory (or vice versa)

### Impact Analysis
- Before extending existing code, search for all usages
- Document current contracts and adaptation requirements
- Consider backward compatibility

## Scripts

The `scripts/` directory contains helper scripts for the ticket workflow:

| Script | Purpose |
|--------|---------|
| `ticket.sh` | Find all documents related to a ticket |
| `next-ticket.sh` | Generate the next available ticket number |
| `open_tickets.sh` | List all open/in-progress tickets |
| `check-ticket-status.sh` | Hook: remind to update ticket status on git add |
| `validate-ticket-status.sh` | Hook: validate ticket status values |

**Configuration:** Each script has a `TICKET_PREFIX` variable at the top. Set this to your project's prefix (e.g., `MYAPP`, `ORD`).

```bash
# Example usage
./scripts/next-ticket.sh          # Returns: PROJ-0001
./scripts/ticket.sh PROJ-0001         # Lists all related docs
./scripts/open_tickets.sh         # Shows open tickets
```

## Hooks

The template includes notification hooks for macOS:
- Notification when Claude needs input
- Notification when a task completes

Ticket validation hooks:
- `./scripts/check-ticket-status.sh` - Runs after Bash commands (reminds to update ticket status)
- `./scripts/validate-ticket-status.sh` - Runs after Edit/Write (validates status values)

## License

This template is provided as-is for use in your own projects. Adapt freely to your needs.
