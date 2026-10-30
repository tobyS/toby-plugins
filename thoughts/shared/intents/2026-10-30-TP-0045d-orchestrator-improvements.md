---
date: 2026-10-30
ticket: TP-0045d
ticket_ref: thoughts/shared/tickets/TP-0045d-orchestrator-improvements.md
source: thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md
size: Medium
status: agreed
last_updated: 2026-10-30
---

# Intent: settle and close the orchestrator improvements collector

## Ticket

TP-0045d (`thoughts/shared/tickets/TP-0045d-orchestrator-improvements.md`),
sub-ticket of the TP-0045 epic. The ticket is the human's; this file is the
agreement on what it means here.

The ticket's checklist is out of date: it lists only the progress lines, while
the first-run findings document marks seven more items `→ TP-0045d`. The table
under "Item routing" is the complete collector from now on.

## Scope

**In:**
- Build the progress lines, or record why the platform does not allow them
  (item A).
- Warn when the project's profile is older than the plugin (item B).
- Close the two contract misses that are still open (items C and D).
- Confirm that items E, F and G are already covered, and tick them with no
  change.
- Create one stub ticket per moved item group (H, I, J, K), each pointing at
  its finding in the findings document.
- Update `CLAUDE.md`'s pointer for the model pins to name the new ticket.
- Bump tce in both manifests and hand over the tag command.
- Tick the ticket's checklist and transition TP-0045d to Done.

**Out:**
- The work of the moved items H, I, J and K (their own tickets).
- Enforcing "the next ticket starts only after the previous pull request is
  merged" (item L, dropped).
- The question form and communication style (TP-0047).
- Defects: a run that breaks is a bug ticket.
- Any change to an agent's contract or a step's working.

### Item routing

| # | Item | Source | State on 2026-10-30 | Route |
|---|------|--------|---------------------|-------|
| A | Progress lines from running agents | Ticket | Open, platform question | Build |
| B | Profile older than the plugin goes unnoticed | Finding 3 | Open: `work.sh` has no version check | Build |
| C | Pull-request body edited after posting, no longer matches the committed dossier | Finding 7 | Nothing in `work-loop.md` covers it | Build |
| D | Dossier's "for you to check" count differs from the verifier's | Finding 7 | Open: `dossier-template.md:104` counts the dossier's own items | Build |
| E | No artifact check after `challenge-fix` | Finding 7 | Covered by the general rule at `work-loop.md:186` | Tick, no change |
| F | Answer headers in the `mode: write` payload | Finding 7 | Covered by `work-dispatch.md:96` | Tick, no change |
| G | No `Understood:`/`Approach:` intro before the questions | Finding 7 | Covered by `work-loop.md:203` | Tick, no change |
| H | Design exploration moves into the intent phase, plus the two `/tce:design_explore` defects (mockup folder name, uncommitted `DECISION.md`) | Finding 1 | Open: still at `planner.md:99` | Move: changes a step's working |
| I | Concerns lost across a session break | Finding 6 | Open | Move: changes every agent's contract |
| J | Delivery vs the ticket backend's completion step, and dossier permalinks that die after a squash merge | Findings 4, 5 | Open | Move, one ticket: both concern what delivery leaves behind |
| K | Model pins for the step agents | Cost section | Open: `CLAUDE.md` says they wait for this ticket | Move: needs a policy and proof on real dispatches |
| L | Enforcing Delivery's "next ticket only after the previous pull request is merged" | TP-0045b plan | A candidate only; no run has asked for it | Drop |

## Observable outcome

Every row of the routing table has a final outcome: shipped with a commit,
ticked as already covered, moved to a named ticket, or dropped with its reason.
A step command shows progress while an agent runs, or the reason it cannot is
on record. A step command run against an older profile shows a prominent
warning and carries on. TP-0045d is Done, so it no longer holds the epic open.

## Anchors

- `plugins/tce/scripts/work.sh` — the `preflight` subcommand
- `plugins/tce/references/work-loop.md` — Step 0 (preflight), Step 6
  (planning), Step 10 (delivery)
- `plugins/tce/references/work-dispatch.md` — the planner payloads
- `plugins/tce/references/dossier-template.md` — the counted-facts line
- `plugins/tce/agents/verifier.md` — dossier mode
- `plugins/tce/agents/planner.md` — the design exploration check (item H, moved)
- `CLAUDE.md` — the "All five agents are `model: inherit`" bullet
- `thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md` — the
  findings the items come from

## Acceptance criteria

- [ ] Each row of the routing table has its final outcome recorded, with a
      commit, a ticket ID or a reason.
- [ ] Items E, F and G are confirmed covered against the current text; any that
      is not moves to Build.
- [ ] Progress is shown on a real foreground dispatch, or the evidence for "not
      possible" is recorded. If showing it would change an agent's contract,
      item A moves to its own ticket instead.
- [ ] A step command run against a profile older than the plugin prints a bold,
      multi-line warning naming both versions and `/tce:init`, and the run
      continues.
- [ ] A profile at the plugin's version prints no warning. So does a project
      with no version marker, whose behaviour stays unchanged.
- [ ] The dossier's count of items to check equals the verifier's.
- [ ] The pull-request body matches the committed dossier after delivery, or
      research shows the edit came from outside tce and the reason is recorded.
- [ ] Every moved item has a ticket that links its finding, and `CLAUDE.md`'s
      pointer for the pins names the new ticket.
- [ ] No agent's contract changes in this ticket.
- [ ] The ticket's checklist is ticked and TP-0045d is Done.
- [ ] tce is bumped in `plugin.json` and `marketplace.json`,
      `claude plugin tag --dry-run ./plugins/tce` passes, and the tag command
      is handed over.

## Decisions

- **Routing as in the table: H, I, J and K move to their own tickets** — over
  folding them into this batch: each changes a step's working or an agent's
  contract, which the ticket rules out, and K rests on one ticket's cost data
  while a wrong pin fails silently.
- **Item L is dropped** — over filing a ticket for it: no real run has asked
  for it, and the profile states it as the human's rule.
- **An older profile warns boldly over several lines and the run continues** —
  over refusing, as the findings document proposed, and over a one-line note:
  init stamps the plugin version, so a refusal would stop every project on each
  plugin bump, even one that changes no config, and one line is too easy to
  miss.
- **This batch closes the collector; later observations get their own tickets**
  — over keeping TP-0045d open for more runs: the epic's done check counts it,
  so an open collector would hold the epic open indefinitely.
- **The run ticks the ticket's checklist itself, as a one-off exception to "no
  session writes into a ticket's body"** — over the human ticking it: the human
  chose this. The exception covers the checklist items only; no other text in
  the ticket changes, and the rule stands everywhere else.

## Open questions

None.

## Questions for research

- [ ] Can a foreground subagent show anything to the human before it returns,
      and by what mechanism (a notification, a file the orchestrator reads,
      or nothing)? Does the orchestrator get a turn while the dispatch runs?
- [ ] Who edited the pull-request body in the GH-37 run: an agent, the
      orchestrator or the human? The findings document does not say.
- [ ] Are items E, F and G covered in behaviour as well as in text? Each was
      checked against the text only when this intent was written.
- [ ] How does the verifier's item list get merged in the dossier, so the two
      counts can differ?
- [ ] How should the profile's version marker be compared with the plugin's,
      given `work.sh preflight` does not read `plugin.json` today?

## Notes

Size: Medium. Most of the work is sorting; the build is four small changes.

The numbers in the Source column are the findings document's. Finding 2 belongs
to TP-0047 and finding 8 was closed there with no action, so neither is an item
here.

This repository's own profile is at config 1.3.0 under tce 1.6.0, so it will
show the new warning until `/tce:init` is re-run.
