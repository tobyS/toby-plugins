# TP-0022: Sync rule for the ticket-sufficiency criteria (three copies)

**Status:** Done
**Estimated Complexity:** Small
**Created:** 2026-07-03
**Updated:** 2026-07-10

## Problem Statement

The three-part ticket-sufficiency definition — scope determinable, outcome
observable, at least one concrete anchor — now lives in three places:

1. `plugins/tce/commands/research.md` ("Ticket Sufficiency Check"),
2. `plugins/tce/commands/work.md` (Phase 1 step 4, mirroring research),
3. `plugins/tce/templates/tce/tickets.md` ("What tce needs from a ticket").

The repo's CLAUDE.md has enforced same-commit sync rules for exactly this kind
of deliberate duplication (the AskUserQuestion block, the composite-tracking
rule, the init/refresh analysis rule) — but this trio is not covered by any of
them. The first time someone edits one copy, the three definitions drift
silently, and research/work would start applying a different sufficiency bar
than the one the template promises ticket authors.

## Desired Outcome

A RULE paragraph in the repo's `CLAUDE.md`, in the same style as the existing
sync rules, that names the three locations, designates which copy is canonical,
and requires all copies to be updated in the same commit. As part of adding the
rule, the three current copies are checked against each other and reconciled if
they have already drifted.

## User Stories / Use Cases

- As the plugin maintainer, I want an explicit rule so that editing the
  sufficiency criteria in one file forces me to update the other two.
- As a future Claude session editing these commands, I want the rule in
  CLAUDE.md so I keep the copies aligned without being told.

## Acceptance Criteria

- [ ] CLAUDE.md contains a rule naming all three locations of the sufficiency
      criteria and requiring same-commit updates, consistent in style with the
      existing duplication rules.
- [ ] The rule designates the canonical copy (decided during planning) so
      conflicts have a resolution order.
- [ ] The three current copies are diffed for existing drift; any divergence is
      reconciled in the same change.
- [ ] No behavioral change to the commands beyond reconciliation (if any drift
      is found).

## Out of Scope

- Changing the sufficiency criteria themselves.
- De-duplicating the copies structurally (commands can't read plugin-internal
  markdown at runtime — the duplication is deliberate, per the core design
  rule; only the sync guarantee is missing).

## Open Questions

None.

## Questions for Research/Planning

- [ ] Which copy is canonical — the template's "What tce needs from a ticket"
      (consumer-facing contract) is the natural candidate; confirm.
- [ ] Whether the rule should fold into an existing CLAUDE.md section (e.g.
      near the AskUserQuestion duplication rule) or stand alone.
- [ ] Whether other small duplicated fragments discovered along the way should
      be added to the same rule (keep scope tight — only if trivially found).

## References

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — Section 4, item 5.
- `CLAUDE.md` — the existing duplication/sync rules this one joins.
- `plugins/tce/commands/research.md`, `plugins/tce/commands/work.md`,
  `plugins/tce/templates/tce/tickets.md` — the three copies.

## Implementation Plan

- Research: `thoughts/shared/research/2026-07-10-TP-0022-sufficiency-criteria-sync-rule.md`
- Plan: `thoughts/shared/plans/2026-07-10-TP-0022-sufficiency-criteria-sync-rule.md`

Single phase: reconcile the one substantive drift (add the "code area" anchor
example to `research.md`, toward the canonical `tickets.md` copy) and add a
standalone semantic-mirror sync rule to `CLAUDE.md` after the AskUserQuestion
rule. Canonical copy = `tickets.md`; register wording left unnormalized;
`work.md` untouched.

## Notes & Updates

### 2026-07-03
Created from the independent plugin review (Fable 5) discussion. Repo-side
change (CLAUDE.md) plus a one-time reconciliation check of the three copies;
no new plugin behavior.

### 2026-07-03 — Out-of-Scope rationale outdated (TP-0016)
The Out-of-Scope assertion "commands can't read plugin-internal markdown at
runtime" is outdated: TP-0016's research verified current docs sanction
runtime reads of plugin files, and TP-0016 introduced the pattern
(`plugins/tce/references/` read via `${CLAUDE_PLUGIN_ROOT}`). The scope
decision itself stands — the sufficiency trio stays as synced copies (the
criteria govern prose in three different contexts, not one moment of use) and
this ticket still only adds the sync rule.

### 2026-07-10 — Implemented (commit `19c04ff`)
Added the `## … keep the three-part test in sync (TP-0022)` rule to `CLAUDE.md`
(after the AskUserQuestion rule): names the three copies, designates `tickets.md`
canonical, requires same-commit substance updates. Framed as a semantic-mirror
rule (register-tolerant) because the copies are intentionally in different
registers (`work.md` compresses, `tickets.md` is prose) — distinct from the
byte-identical AskUserQuestion rule. Reconciled the one substantive drift: added
the "code area" anchor example to `research.md`'s sufficiency check. Register
wording left unnormalized and `work.md` untouched, per the checkpoint decisions.
Plan-Compliance Gate: 0 not met (6 met, 3 validator checks run and passing, 4
manual items verified). Status → Done.
