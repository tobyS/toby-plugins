<!--
Runtime reference for the tce intent. Read at the moment of writing an intent
document by /tce:intent — always in full, even if already read earlier in the
session. Never copied into consuming projects.

Changes to this file are command-contract changes. Downstream consumers depend
on it: scripts/stage.sh finds an intent by its filename (the canonical ticket
ID as a delimited segment — a ticketless intent by its slug), the step agents
(researcher, planner, plan-challenger, implementer, verifier) and /tce:review
read it right after the ticket, and the step commands take a ticketless
intent by path (work-loop.md's Entry reads its `ticket:` line). The frontmatter
fields `ticket` and `last_updated` are read downstream. When you change the
sections, the frontmatter or the naming, the CLAUDE.md intent rule applies
(update commands/intent.md, scripts/stage.sh and commands/list.md in the same
commit).

Contents:
1. The intent document template (YAML frontmatter + all body sections)
2. Rules for filling it
-->

# Intent document template

The intent is the agreement between the human and the agents on what a piece
of work means in this codebase. The ticket (if there is one) belongs to the
ticket system and is never modified; everything agreed lands here.

Structure the intent with YAML frontmatter followed by content:

```markdown
---
date: YYYY-MM-DD
ticket: [PREFIX]-XXXX        # or: none
ticket_ref: <path or URL per tickets.md>   # or: none
source: <thoughts/ document path the intent was drafted from>   # omit if none
size: Small | Medium | Large | Extra Large
status: agreed | open-questions
last_updated: YYYY-MM-DD
last_updated_note: "<what changed>"   # only after an update
---

# Intent: [title]

## Ticket

[Pointer to the ticket ([PREFIX]-XXXX, path or URL). The ticket is the human's;
this file is the agreement on what it means here. "None — ticketless: <one line
on where the input came from>" when there is no ticket.]

## Scope

**In:**
- [what changes or gets built]

**Out:**
- [explicitly excluded]

## Observable outcome

[What is true when this is done — concrete enough to check.]

## Anchors

- [concrete pointer into the system: feature, screen, command, error message,
  file or code area — each confirmed to exist]

## Acceptance criteria

- [ ] [specific, testable criterion]

## Decisions

- **[decision]** — over [rejected alternative]: [one-line why]

## Open questions

[Business/product questions still unresolved — blockers. "None." when empty.]

## Questions for research

- [ ] [codebase/technical questions deferred to research and planning]

## Notes

[Size reasoning, sources, anything agreed that fits nowhere above.]
```

## Rules

- `status: open-questions` if and only if `## Open questions` is not "None.";
  otherwise `status: agreed`.
- The Decisions line shape is fixed — `- **<decision>** — over <rejected
  alternative>: <why>`. Every decision names the alternative it rejected; the
  orchestrating `/tce:work`'s plan `## Decisions` section mirrors this shape.
- No section is left empty without agreement. A section the human agreed to
  leave empty says so ("None." or "None — <why>").
- Anchors are confirmed to exist in the codebase, never guessed.
- `ticket: none` and `ticket_ref: none` for a ticketless intent; the `## Ticket`
  section then says where the input came from.
- On an update, keep `date`, set `last_updated` to today and
  `last_updated_note` to a one-line summary of what changed.
