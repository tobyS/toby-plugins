<!--
Runtime reference: the dispatch / ask / resume loop of tce's step commands.
Read at the point of use — always in full, even if already read earlier in the
session — by /tce:work, /tce:research, /tce:plan, /tce:implement and
/tce:quickfix, each of which runs it in its own lane (the steps it runs, the
rows it starts from, where it stops). Never copied into consuming projects.

This file is the one description of the loop: the commands carry only their
lane, and the agents carry each step's working. Changes to this file are
command-contract changes under the CLAUDE.md rule "tce: the step commands are
orchestrators" (the loop span: this file, work-dispatch.md, work-brief.md and
the five commands' lanes). It carries one copy of the AskUserQuestion dialog
guidelines block, byte-identical to the others.

Contents:
1. AskUserQuestion dialog guidelines
2. Invariants
3. Entry (ticket ID or intent path)
4. Steps 0–12
5. Lanes
-->

# The step loop

Throughout this file, `<command>` is the name of the command running the loop
(e.g. `/tce:work`), `<argument>` is its argument as the user gave it (a ticket
ID or an intent path), and `<ID>` is the canonical ticket ID — or, for a
ticketless intent, the intent's slug (see Entry). `[PREFIX]-XXXX` stands for a
canonical ticket ID as `tickets.md` defines it.

### AskUserQuestion dialog guidelines

When asking the user something, follow these rules:

- Use the AskUserQuestion tool when a small set of concrete options exists
  (2–4); ask in plain prose only when the answer is genuinely free-form.
- Print a short intro paragraph (1–3 plain sentences) as a normal message
  before invoking the tool — it carries all context. The question text contains
  only the question itself: no background, no nested parentheticals.
- Put the recommended or detected option first, append " (Recommended)" to its
  label, and give the reasoning (e.g. how it was detected) in that option's
  description.
- At most 4 questions per call — batch related questions into one call. Never
  offer an "Other" or "custom" option: the tool adds one automatically.
- Headers ≤12 characters; labels 1–5 words; descriptions 1–2 plain sentences on
  what choosing the option means. Plain text only — markdown is not rendered
  inside the dialog.
- Use multiSelect only when choices are not mutually exclusive, and phrase the
  question accordingly.

**One exception, for the planner's questions (Step 6):** there the first
question's text also carries the `Understood:` and `Approach:` lines from the
planner's return, copied line by line with their labels, above the question.
Real runs left a message before the dialog out, however it was worded; the
dialog is what they always send.

---

## Invariants

1. **One agent per step, in the foreground.** Dispatch with "Use the
   tce:<agent> agent" and wait for its result: `tce:researcher`,
   `tce:planner`, `tce:plan-challenger`, `tce:implementer`, `tce:verifier`.
2. **Artifacts travel by path, never by contents.** Payloads are the
   `key: value` lines in `work-dispatch.md`; you never paste a document into a
   prompt and never read the research's or plan's body. You read only what the
   position table names, the agents' returns, and the ticket (for a ticketless
   intent: the intent).
3. **You never edit code, the research or the plan's body.** Your only writes
   are the plan's `## Implementation Closeout`, the ticks on Manual items the
   human confirmed (Step 12), the ticket's done transition and the delivery.
4. **Only `needs decision` and `blocked` reach the human**, plus the planning
   questions, the brief and the closing confirmation of items left for them.
   `done with concerns` never stops the run.
5. **Ask through AskUserQuestion**, so the whole run stays in one turn — the
   running command's `allowed-tools` grant the scripts for this turn only.
6. **The position is re-derived from disk** after every step, never
   remembered.

## Entry

The argument is a ticket reference **or** a path into
`thoughts/shared/intents/`.

- **A ticket reference** (as `tickets.md` defines it) → a ticket run; `<ID>`
  is its canonical ID.
- **A path into `thoughts/shared/intents/`** → grep the file's `ticket:`
  frontmatter line. A ticket ID → continue exactly as for that ticket. `none`
  → a **ticketless** run: `<ID>` is the intent's **slug** — its filename
  without the leading `YYYY-MM-DD-` and the `.md` — and every payload carries
  `ticket: none`, `ticket-file: none` and `intent: <that path>`. If the file
  is not on the current checkout and `profile.md`'s `## Branch convention`
  says **Branch per ticket**, it may live only on its own branch: treat the
  run as ticketless with `<ID>` = the filename's slug, and check its
  `ticket:` line at the end of Step 2 instead. With no file and any other
  convention, it is "anything else".
- **Anything else** (no argument, free text, another path) → refuse and stop
  with the running command's usage line and: "Write an intent first with
  `/tce:intent`, or explore with `/tce:discuss`."

## Step 0 — Preflight

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/work.sh" preflight`. Unless both
`foreground:` and `timeout:` say `ok`, your **entire reply** is the five lines
between the fences below, **exactly as written**
— every character and line break; the fence lines are not part of it, so do
not wrap it in a code block; nothing before it, nothing after it, no mention
of the check's output and no re-run line — and stop:

```
This tce command needs foreground agents and a long Bash timeout. Quit Claude Code,
then start it again with:

  export CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1
  export BASH_DEFAULT_TIMEOUT_MS=600000
```

Otherwise, if `profile:` says `older <profile version> <plugin version>`, the
output ends with a three-line warning in bold. Your next message, before any
other tool call, is those three lines **exactly as written** and nothing else
— every character and line break, no sentence of your own around them, no
summary of them at the end of the run — and you carry on with the run in the
same turn. Print it once per run: `/tce:quickfix` reaches this step twice. Any other `profile:` value prints nothing.

## Step 1 — Ticket

Resolve the canonical ticket ID as `tickets.md` describes. Read the ticket now,
fully, with `tickets.md`'s read mechanism — even if it appeared earlier in this
conversation. Ticketless: there is no ticket; read the intent at the end of
Step 2 instead, fully — it is the input, and it may live only on its branch.

## Step 2 — Branch

Read the `## Branch convention` section of `profile.md`. If it is absent or says
**Current branch**, skip this step entirely and print nothing (ticketless: then
read the intent now, as Step 1 says). If it says
**Branch per ticket**, resolve the branch name from the recorded pattern (a
`<slug>` element is a short kebab-case slug of the ticket title) — ticketless:
the **ticketless branch name**, the recorded pattern with the intent's slug
substituted for `<ticket-id>` and a `<slug>` element dropped together with one
adjoining separator (`-`, `_` or `/`), so `<ticket-id>-<slug>` and
`<ticket-id>` both give `<intent-slug>`, and `feature/<ticket-id>` gives
`feature/<intent-slug>` — and run
`"${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" switch <branch>`: `switched` or
`already` → continue (one line naming the branch); `missing` → refuse as in
Step 3 point 2 — `/tce:intent` cuts the ticket branch before it writes the
intent, so a missing branch means there is no intent yet, and `<command>` never
cuts one itself; `dirty` → ask the user to commit or stash, then re-run;
`blocked` → report the `detail:` line and stop.

`missing` on a ticketless run has one exception:

- The intent file is on the current checkout (an intent written before tce
  1.6.0, committed where the session is) → run
  `"${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" create <branch> <base> <remote> --trust-local`.
  `created` → print one line: "Cut <branch> from the local <base>, which
  holds this intent (written before tce 1.6.0)."; `dirty` → ask the user to
  commit or stash, then re-run; any other result → report the `detail:` line
  and stop.
- Otherwise → refuse and stop: "No intent at <path> — write one with
  `/tce:intent`."

Ticketless, after the branch is in place: if the intent file is not on disk,
stop: "<branch> does not contain <path>; switch to the branch that holds the
intent and re-run `<command> <argument>`." Otherwise read the intent now,
fully; if its `ticket:` line is not `none`, refuse and stop: "<path> is
<that ticket>'s intent — run `<command> <that ticket>`."

## Step 3 — Intent and parent

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" <ID>` and
   `"${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh" <ID>`.
2. If `stage.sh`'s `intent:` line is empty, refuse and stop:
   "No intent for <ID> — run `/tce:intent <ID>` first."
3. If the ticket has a parent (per `tickets.md`'s "Parent / epic tickets"), run
   `ticket.sh` for the parent too; its ticket, research and plan paths become
   the `parent:` field. Ticketless: `parent: none`.
4. A ticket that involves a non-trivial UX change gets no design exploration
   inside this flow: the planner asks whether to stop for
   `/tce:design_explore`.

## Step 4 — Position

Read `${CLAUDE_PLUGIN_ROOT}/references/work-dispatch.md` **now — in full**, and
take the first row of its position table that matches. If that row is not
among your lane's start rows, print your lane's *otherwise* line and stop.
Otherwise print one line:
"<ID>: continuing at <step> (phases done: <k>/<N>)" — leave out the
parenthesis before a plan exists. Then run the steps below from there, in
order, re-running `stage.sh` (and the table) after each, and only those steps
your lane names; after its last one, print what the lane says and stop.

**Every dispatch** uses the payload `work-dispatch.md` gives for that agent and
mode. **Every return** is read for its `tce-return` block:

- Missing or unreadable → resume the agent once with the retry note from
  `${CLAUDE_PLUGIN_ROOT}/references/agent-returns.md`, verbatim; a second
  failure is `blocked`.
- `artifact:` names a path → run
  `"${CLAUDE_PLUGIN_ROOT}/scripts/work.sh" artifact <path>`; anything but
  `yes`/`yes`/`yes` is `blocked`, naming the failed check.
- `blocked`, or `needs decision` outside planning → render it per
  `work-dispatch.md` and stop.
- `done with concerns` → keep the concerns for the dossier and continue.

## Step 5 — Research

Dispatch `tce:researcher`. When its summary names config drift, keep its
drift line for the final summary: "Research found tce config looks stale
(<what drifted>) — consider `/tce:refresh`."

## Step 6 — Planning (the only place you ask)

1. Read `${CLAUDE_PLUGIN_ROOT}/references/work-brief.md` **now — in full**.
2. Dispatch `tce:planner` with `mode: questions`. If it returns questions,
   the first question's text starts with its `Understood:` and `Approach:`
   lines, copied line by line, labels included, then a blank line, then the
   question (the exception under the dialog guidelines above); never invoke
   AskUserQuestion without them. Ask every question through AskUserQuestion —
   one decision per question, its options exactly as returned (recommended
   first), at most four per call. A header over 12 characters is shortened for the dialog. If
   the human chose to stop for design exploration, stop: "Run
   `/tce:design_explore <ID>` (ticketless: describe the UX question to
   `/tce:design_explore`), then `<command> <argument>` again." Otherwise
   resume the planner with `mode: write` and the answers verbatim, each under
   the header the dialog showed (`answers: none` when there were none). A
   `needs decision` from `write` is another round of the same.
3. Dispatch `tce:plan-challenger` with the planner's brief. On `needs
   decision`, resume the planner with `mode: challenge-fix` and the failing
   lines, run Step 4's artifact check on the plan it names, then challenge
   again — at most 3 rounds; then stop with `needs decision`. Keep its human
   items.
4. Print the brief exactly as the planner returned it, then the challenger's
   human items under "Challenger notes:". If "Decisions for you" is not
   `None.`, ask those first, as in point 2, resume the planner with
   `mode: revise` and `push-back:` carrying each question's header and the
   answer, run Step 4's artifact check on the plan it names, re-run the
   challenger, and print the delta. Then ask:

   Question: "Approve the plan?" — header: "Plan", options:

   1. **Approve (Recommended)** — Implementation starts now and runs to the
      dossier without further questions unless something blocks.
   2. **Stop here** — The plan stays committed; re-run <command> to come back
      to this approval.

   A free-text answer is a push-back: resume the planner with `mode: revise`
   and the text verbatim, run Step 4's artifact check on the plan it names,
   re-run the challenger, print the delta, and ask again. When this step is
   reached from the position table with a plan already written, dispatch the
   planner with `mode: brief` first.

## Step 7 — Implement

1. **Repository state check.** Grep the research document's `git_commit:`
   frontmatter line and run
   `"${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh" <git_commit> <research-path>`.
   Pass its `baseline:` to every implementer dispatch as `research-baseline:`
   (or `none` on `source: none`); the implementer spot-checks what changed
   since.
2. For each phase `k + 1` to `N`, dispatch `tce:implementer` with
   `mode: phase`. When the plan has no `**Base commit**` yet (grep), first run
   `git rev-parse HEAD` and pass it as `base-commit:`. After each return,
   re-run `stage.sh`; continue only when `progress:` moved.

## Step 8 — Verify

1. Resolve the base commit: the plan's first `**Base commit**` (grep); failing
   that, a `**Base commit**` in a legacy `.status.md` next to the plan; failing
   that — ticket runs only — the parent of
   `git log --grep="[PREFIX]-XXXX" --format=%H | tail -1` (this finds
   something only when the commit convention puts the ticket ID in messages).
   Run `"${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh" <base> <plan-path>`. With
   no base at all, or on `source: none`, stop as `blocked`: the gate cannot
   run against a real diff — never guess a baseline.
2. Dispatch `tce:verifier` with `mode: verify`, the `baseline:` and its
   `source`.
3. On `needs decision`: read the last phase's `Final fix rounds` (grep). Below
   3/3 → dispatch `tce:implementer` with `mode: fix` and the verifier's lines,
   then verify again. At 3/3 → stop with `needs decision` and the evidence.

## Step 9 — Dossier

Dispatch `tce:verifier` with `mode: dossier` and the run's concerns. Its
artifact check covers the dossier.

## Step 10 — Delivery

Read the `## Delivery` section of `profile.md`.

- **Absent or Direct:** the dossier is printed in Step 11. Merge reference:
  `direct: <branch> @ <short sha>`.
- **Pull request:** the base branch and remote come from the Branch convention.
  Run `git push -u <remote> <branch>`. Then run `gh pr view <branch> --json url`:
  if a pull request exists (a session died after opening it), use its URL;
  otherwise run
  `gh pr create --base <base> --head <branch> --title "[PREFIX]-XXXX: <ticket title>" --body-file <dossier-path>`
  — ticketless: `--title "<intent title>"`, the intent's `# Intent: `
  heading with that prefix stripped.
  `gh pr view` exiting non-zero because no pull request exists is the normal
  case, not a failure. If any other command fails, stop as `blocked` with its
  last output line. The merge
  reference is the pull request's URL. tce never merges.

**When your lane says *no delivery*:** run no command of this step. Direct → merge reference `direct: <branch> @ <short sha>`; Pull request →
merge reference `undelivered: <branch> @ <short sha>` (run
`/tce:work <argument>` to deliver).

**Reached from position row 1** (the Closeout's Merge reference says
`undelivered:`): deliver as above, then rewrite that Closeout line with the
new merge reference, commit the plan with the `/tce:commit` command (under
Pull request delivery, `git push` again), and re-derive the position.

## Step 11 — Closeout and summary

1. Append to the plan:

   ```markdown
   ## Implementation Closeout

   - **Plan-compliance gate**: [the verifier's verify summary, one line]
   - **Manual verification**: [verified by agent | pending: <items for you to check>]
   - **Merge reference**: [from Step 10]
   - **Ticket**: [PREFIX]-XXXX → Done   (or: → Done once the items above are checked; ticketless: none (ticketless intent))
   ```

2. If nothing is left for the human to check, make the done transition per
   `tickets.md`'s "Status / completion" (for tmt: `**Status:** Done`); if the
   policy says tce does not transition, say which transition is due.
   Ticketless: skip — there is no ticket.
3. Commit the plan and the ticket (ticketless: the plan) with the
   `/tce:commit` command; under Pull request delivery, `git push` again.
4. Print the summary: under Direct, the dossier's text; under Pull request,
   the URL and the dossier's counted-facts line. Add the config-drift line if
   Step 5 kept one. If items are pending, continue with Step 12.

## Step 12 — Items for you to check

Reached from Step 11, or from the position table when the Closeout says
`pending:`. Restate every pending item in full — what to run or do and what
pass looks like (from the plan's `## Verification`) — then ask:

Question: "Have you checked the items above?" — header: "Checked", options:

1. **All pass** — I tick them in the plan, mark the ticket done and commit.
2. **Not yet** — Nothing changes; re-run <command> when you have checked them.

- **All pass:** tick each pending Manual item in the plan, appending
  ` — confirmed by user YYYY-MM-DD`; set the Closeout's Manual verification
  line to `confirmed by user YYYY-MM-DD` and its Ticket line to `→ Done`
  (ticketless: leave it); make the done transition per `tickets.md`
  (ticketless: skip); commit with `/tce:commit` (and `git push` under Pull
  request delivery).
- **Not yet:** stop.
- **A free-text answer** reports a failure: keep the Closeout's Manual
  verification line `pending:`, append ` — last check failed: <the human's
  text, one line>`, commit, and stop with a `needs decision` that names it.
  Fixing it is the human's call — a new ticket, or a fix — and a re-run asks
  this question again.

## Lanes

Each command that runs this loop names its **lane** in its own body. Read it
as:

- **Start rows** — the rows of `work-dispatch.md`'s position table the command
  acts on. Any other row → the *otherwise* line.
- **Steps** — which of Steps 5–12 it runs, and any variant (e.g. Step 10 *no
  delivery*); after its last step it prints what the lane says and stops.
- **Otherwise** — what it prints when the matched row is not a start row,
  by default "<ID> is at <step>; next: `<next command> <argument>`", and then
  it stops.

Steps 0–4 run in every lane.
