---
date: 2026-10-27
ticket: TP-0045e
ticket_ref: thoughts/shared/tickets/TP-0045e-defects-from-stage-2-run.md
size: Large
status: agreed
last_updated: 2026-10-27
last_updated_note: "Added: ticketless runs, quickfix included, follow the Branch convention and Delivery like ticket runs"
---

# Intent: defects found in the stage-2 verification run

## Ticket

TP-0045e (`thoughts/shared/tickets/TP-0045e-defects-from-stage-2-run.md`),
sub-ticket of the TP-0045 epic. The ticket is the human's; this file is the
agreement on what it means here.

## Scope

**In:**
- Autonomous `/tce:intent` returns exactly its one return line, and
  `/tce:quickfix` reads that line reliably.
- The preflight refusal reaches the user as the fixed block.
- Establish why the `allowed-tools` script grants did not match under headless
  `claude -p`; then fix the grant or document the limitation.
- A run interrupted between a phase commit and its log commit never folds the
  log edit into a later feature commit.
- Ticketless runs — `/tce:quickfix` and every step command or `/tce:work`
  given an intent path — follow the profile's `## Branch convention` and
  `## Delivery` exactly as ticket runs do: under Branch per ticket they work
  on a branch named from the pattern with the intent's slug in place of the
  ticket ID; under Pull request delivery `/tce:quickfix` and `/tce:work`
  push and open the pull request with the dossier. Reported by the user on a
  real `/tce:quickfix` run (2026-10-27); it reverses TP-0045c's "ticketless
  never branches, always Direct" decision.
- tce version bump and tag.

**Out:**
- TP-0045d's improvements (progress heads-up lines and the like).
- Any agent return-contract change beyond what a fix needs.
- Analogous issues in tsf or tle.
- Widening `/tce:init`'s allowlist as a workaround for the headless grant
  issue.

## Observable outcome

Re-running the four reproductions from TP-0045c's verification in a scratch
consuming project shows: only the `insufficient:` line from an autonomous
intent; the preflight block exactly as written; a documented answer for
headless permissions; and, after an interruption, the plan log edit committed
on its own rather than inside the next phase's feature commit. In a project
with Branch per ticket and Pull request delivery, `/tce:quickfix "<fix>"`
leaves the intent, research, plan, code and dossier on its own branch and ends
with an open pull request; under Current branch and Direct it behaves as
today.

## Anchors

- `plugins/tce/commands/intent.md` — `## Autonomous mode`, step 6 "Return"
- `plugins/tce/commands/quickfix.md:43-44` — where quickfix reads `intent:` /
  `insufficient:`
- `plugins/tce/references/work-loop.md:90-99` — Step 0 Preflight and its fixed
  block
- `plugins/tce/scripts/work.sh` — the `preflight` subcommand
- The `allowed-tools` lines of `plugins/tce/commands/research.md`, `plan.md`,
  `implement.md`, `quickfix.md` and `work.md`
  (`Bash("${CLAUDE_PLUGIN_ROOT}/scripts/…":*)` form)
- `plugins/tce/agents/implementer.md:138-149` — the log's `**Commit**` line and
  the follow-up plan commit
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
- Evidence: `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md:860`,
  `:924`, `:926`

## Acceptance criteria

- [ ] Autonomous `/tce:intent` on an insufficient description prints exactly
      one line, `insufficient: <part> — …`, and nothing before or after it.
- [ ] `/tce:quickfix` continues or stops correctly even if the intent step
      emits other text before its return line — by an explicit rule, not by
      luck.
- [ ] With `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` unset, every step command's
      refusal shows the Step 0 block byte for byte.
- [ ] The headless grant issue is reproduced or ruled out in both an
      interactive and a `claude -p` session; the result is either corrected
      `allowed-tools` entries that match in both, or a tce README note naming
      the headless limitation and the CLI flag that works around it.
- [ ] Killing a run right after a phase commit and re-running it leaves no
      plan log edit inside the next phase's feature commit — either one commit
      carries phase and log, or the stray edit is committed on its own first.
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

- **One sub-ticket and one release for all four defects** — over four
  tickets: each fix is small and they share the verification setup.
- **For the headless grant issue, establish the cause first and document a
  platform limit rather than work around it** — over adding the scripts to
  `/tce:init`'s allowlist: CLAUDE.md forbids widening that allowlist.
- **A fixed message counts only if it reaches the user verbatim** — over "the
  message mentions the export lines": a paraphrase is exactly what failed.
- **Ticketless runs follow the Branch convention and Delivery like ticket
  runs** — over TP-0045c's "ticketless never branches, always Direct": in a
  branch-per-ticket, PR-reviewed project a quickfix landing on the base branch
  bypasses the project's own review flow.
- **The rule applies to every ticketless run, not only `/tce:quickfix`** —
  over a quickfix-only exception: one rule in `work-loop.md` instead of a
  special case.
- **The branch name substitutes the intent's slug for the ticket ID in the
  existing pattern** — over a separate ticketless pattern in the profile: no
  new profile field, so no template / init / refresh / README change.
- **Under Pull request delivery, `/tce:quickfix` pushes and opens the pull
  request** — over branching only and leaving delivery to `/tce:work`: a small
  fix ends reviewable in one command.

## Open questions

None.

## Questions for research

- [ ] Can a prompt-level "print verbatim" be made reliable, or must the fixed
      text come from script output (as `work.sh preflight` already prints
      `detail:`)?
- [ ] How are `${CLAUDE_PLUGIN_ROOT}` patterns in `allowed-tools` matched after
      substitution, interactive versus `claude -p`?
- [ ] Can the implementer record the log hash without a second commit (log
      written before the commit, or a re-run committing a stray log edit
      first)?
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

Size Large (was Medium): four independent small fixes, one of which (the
headless grant issue) needs investigation first, plus the ticketless
branch/delivery change, which touches the shared loop, quickfix, the
autonomous intent and two CLAUDE.md spans. The four defects were recorded as
concerns in
`thoughts/shared/dossiers/2026-10-17-TP-0045c-single-step-commands-on-agents.md`;
the ticketless branch/delivery gap was reported by the user on a real
`/tce:quickfix` run on 2026-10-27 and added to this intent then. It is not in
the ticket text, which stays as its author wrote it.
