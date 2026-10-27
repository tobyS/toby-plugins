---
date: 2026-10-27
ticket: TP-0045f
ticket_ref: thoughts/shared/tickets/TP-0045f-ticketless-branch-and-delivery.md
size: Medium
status: agreed
last_updated: 2026-10-27
---

# Intent: ticketless runs follow the branch convention and delivery

## Ticket

TP-0045f (`thoughts/shared/tickets/TP-0045f-ticketless-branch-and-delivery.md`),
sub-ticket of the TP-0045 epic. The ticket is the human's; this file is the
agreement on what it means here.

## Scope

**In:**
- Ticketless runs — `/tce:quickfix` and every step command or `/tce:work`
  given an intent path — follow the profile's `## Branch convention` and
  `## Delivery` exactly as ticket runs do.
- Under Branch per ticket they work on a branch named from the existing
  pattern with the intent's slug in place of the ticket ID.
- Under Pull request delivery `/tce:quickfix` and a ticketless `/tce:work`
  push and open the pull request with the dossier.
- CLAUDE.md's TP-0031 and Delivery rules and the tce README updated to match.
- tce version bump and tag.

**Out:**
- The four defects of TP-0045e.
- New profile fields or options (no separate ticketless branch pattern).
- Changes to how ticket runs branch or deliver.

## Observable outcome

In a project with Branch per ticket and Pull request delivery,
`/tce:quickfix "<fix>"` leaves the intent, research, plan, code and dossier on
its own branch and ends with an open pull request. Under Current branch and
Direct delivery it behaves as in tce 1.5.0.

## Anchors

- `plugins/tce/references/work-loop.md:112` (Step 2: "Ticketless: skip this
  step entirely") and `:239` (Step 10: "Ticketless: always Direct")
- `plugins/tce/commands/quickfix.md:16` and `:83-84` ("Never branch, push or
  deliver")
- `plugins/tce/commands/intent.md:428` (autonomous mode: "There is no branch
  step")
- `plugins/tce/scripts/branch.sh` — `create` / `switch`
- `CLAUDE.md:325` and `:347-348` (TP-0031 span: ticketless intents never
  branch; non-ticket work stays where the session is) and `:398` (ticketless
  runs always Direct)

## Acceptance criteria

- [ ] Under Branch per ticket, a ticketless run (`/tce:quickfix`, or a step
      command / `/tce:work` on an intent path) works on the branch named by
      the profile's pattern with the intent's slug substituted for the ticket
      ID, and the intent, research, plan, code and dossier commits all land
      on that branch — none on the base branch.
- [ ] Under Pull request delivery, `/tce:quickfix` and a ticketless
      `/tce:work` push that branch and open a pull request whose body is the
      dossier; `/tce:research`, `/tce:plan` and `/tce:implement` on an intent
      path behave as they do for a ticket (no push; implement records
      `undelivered:`).
- [ ] When the base branch cannot be brought up to date, a ticketless run
      stops and asks exactly as a ticket run does; it never cuts the branch
      from a stale base silently.
- [ ] Under Current branch and Direct delivery (or with the sections absent),
      ticketless runs behave byte-identically to tce 1.5.0.
- [ ] CLAUDE.md's TP-0031 and Delivery rules no longer say ticketless work
      never branches or is always Direct, and the tce README describes the
      ticketless behaviour.
- [ ] `claude plugin validate` passes for the marketplace and all four plugins.
- [ ] tce version bumped in both manifests and tagged.

## Decisions

- **Ticketless runs follow the Branch convention and Delivery like ticket
  runs** — over TP-0045c's "ticketless never branches, always Direct": in a
  branch-per-ticket, PR-reviewed project a quickfix landing on the base branch
  bypasses the project's own review flow.
- **The rule applies to every ticketless run, not only `/tce:quickfix`** —
  over a quickfix-only exception: one rule in `work-loop.md` instead of a
  special case.
- **The branch name substitutes the intent's slug for the ticket ID in the
  existing pattern** — over a separate ticketless pattern in the profile: no
  new profile field, so no template / init / refresh / README change for it.
- **Under Pull request delivery, `/tce:quickfix` pushes and opens the pull
  request** — over branching only and leaving delivery to `/tce:work`: a small
  fix ends reviewable in one command.
- **Its own sub-ticket of the epic** — over folding it into TP-0045e: it is a
  design change, not a defect cleanup.

## Open questions

None.

## Questions for research

- [ ] Where the ticketless branch is cut: the autonomous intent is the first
      artifact, but its slug is chosen inside `/tce:intent --autonomous` —
      does quickfix cut the branch before or after it, and how does the base
      branch stop-and-ask dialog reach the human from an autonomous step?
- [ ] What the pull request title is without a ticket (the intent's title?),
      and how a slug that is not a valid branch-name segment is handled.
- [ ] Which of the TP-0031 span files (`branch.sh` callers, CLAUDE.md) and
      the Delivery span change, and whether `/tce:quickfix`'s `allowed-tools`
      needs `branch.sh`, `git push` and `gh pr` grants like `work.md`.

## Notes

Size Medium: one behaviour rule, but it reaches the shared loop, quickfix, the
autonomous intent and two CLAUDE.md spans. Reported by the user on a real
`/tce:quickfix` run on 2026-10-27; first drafted into TP-0045e's intent and
split out the same day.
