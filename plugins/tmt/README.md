# tmt — Toby Markdown Tickets

`tmt` is a lightweight ticket tracker that lives **inside your repo**: every
ticket is a plain markdown file in `thoughts/shared/tickets/`, named
`<PREFIX>-0001-brief-description.md` and tracked in Git alongside the code. No
server, no account, no sync — `git log` is your audit trail and `grep` is your
search.

It was split out of the [tce](../tce/README.md) context-engineering workflow,
where it served as the built-in ticket system. It works standalone, and it
remains tce's native ticket backend: if you use both, `/tmt:create` is step 1 of
the tce chain (ticket → research → plan → implement).

## What you get

- **Guided ticket creation** (`/tmt:create`) — an interactive dialogue that
  shapes an idea into a business-focused ticket: problem, desired outcome, user
  stories, testable acceptance criteria, explicit out-of-scope, and open
  questions. WHAT and WHY, not HOW.
- **Sequential numbering** — tickets are `<PREFIX>-0001`, `<PREFIX>-0002`, …;
  sub-tickets of an epic get a letter suffix (`<PREFIX>-0057a`). The
  `next-ticket.sh` script derives the next free number from the files on disk,
  so the repo itself is the counter.
- **Status lifecycle with enforcement** — every ticket carries
  `**Status:** Open | In Progress | Done | Rejected`. Two hooks keep it honest:
  an Edit/Write hook rejects invalid status values, and a `git add` hook reminds
  Claude to update the status of tickets touched by the commit.
- **Open-ticket overview** (`/tmt:list`) — all Open/In Progress tickets with
  title and complexity (plus their tce research/plan documents, if you use tce).

## Requirements

| Tool | Needed for                                      | Required?                                                                                              |
| ---- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `git`| everything (the tickets live in your repo)      | **Required**                                                                                           |
| `jq` | the ticket-status hooks parse hook JSON with it | **Required** for the hooks; without it the status reminders silently don't fire (work is not blocked)  |

The scripts are pure filesystem (`find` over `thoughts/`) — no network, auth, or
GitHub access.

## Install

```bash
# Add the marketplace (once per machine), then install the plugin:
/plugin marketplace add tobyS/toby-plugins
/plugin install tmt@toby-plugins
```

## Set up a project

```bash
/tmt:init
```

This agrees a ticket prefix with you (short, uppercase, e.g. `MYAPP`) and writes:

```
.claude/tmt/
└── config                    # TICKET_PREFIX=<PREFIX>  (read by the scripts & hooks)
thoughts/shared/tickets/      # tickets live here
```

Commit both — they're shared project config, not personal settings. If the
project was set up by an old tce version (prefix in `.claude/tce/config`),
`/tmt:init` detects and adopts it; until you run it, the scripts also fall back
to the legacy location, so nothing breaks mid-migration. Projects set up from
the original [claude-template](https://github.com/tobyS/claude-template) are
detected too: `/tmt:init` harvests the prefix hardcoded in the template's
`scripts/*.sh`, and — after listing them and asking — removes the superseded
ticket scripts, `create_ticket.md`, and the template's duplicate hook entries
in `.claude/settings.json`. Existing tickets are never touched.

## Commands

| Command       | Purpose                                                      |
| ------------- | ------------------------------------------------------------ |
| `/tmt:init`   | Agree a ticket prefix and write `.claude/tmt/` config        |
| `/tmt:create` | Create a ticket through guided business-focused discussion   |
| `/tmt:list`   | List open tickets                                            |

## Ticket format

```markdown
# MYAPP-0042: Document tagging

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-06-11
**Updated:** 2026-06-11

## Problem Statement
## Desired Outcome
## User Stories / Use Cases
## Acceptance Criteria
## Out of Scope
## Open Questions
## Questions for Research/Planning
## References
## Implementation Plan
## Notes & Updates
```

The first line and the `**Status:**` / `**Estimated Complexity:**` fields are
machine-read by the scripts and hooks; everything else is free-form markdown for
humans (and for Claude — the section structure deliberately feeds the tce
workflow's research and planning phases).

## Using tmt with tce

tce (v2+) is ticket-system-agnostic and reads the project's
`.claude/tce/tickets.md` to learn how to work with tickets. Running `/tce:init`
in a project where tmt is set up detects it and generates that file for the tmt
backend automatically. `/tmt:create` in turn honors tce's "What tce needs from a
ticket" expectations when that file exists — the two plugins coordinate through
project config, not through each other.

## Update

```bash
/plugin marketplace update toby-plugins
```
