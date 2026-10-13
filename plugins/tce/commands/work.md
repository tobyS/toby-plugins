---
description: Orchestrate a ticket with an intent from research to a verified, delivered change — one fresh agent per step, questions only during planning. Needs CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 and BASH_DEFAULT_TIMEOUT_MS=600000.
argument-hint: "[ticket-id]"
disable-model-invocation: true
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/work.sh":*), Bash(git rev-parse:*), Bash(git log:*), Bash(git push:*), Bash(gh pr create:*), Bash(gh pr view:*)
---

# Work on Ticket

Take a ticket that has an intent from research to a verified, delivered change.
You are the **orchestrator**: each step runs in a fresh agent, the documents
they write are the run's state, and the human is asked only during planning —
and, at the end, to confirm what the run could not check itself.

## Project context

This command ships in the **tce** workflow plugin and is stack- and
ticket-system-agnostic.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` (branch convention,
  delivery, reader) and `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` (how to
  resolve and read a ticket, parent tickets, the status policy). If either is
  missing, tell the user to run `/tce:init` and stop.
- `[PREFIX]-XXXX` stands for a canonical ticket ID as defined in `tickets.md`
  (e.g. `MYAPP-0042`, `GH-123`) — you never hardcode a prefix.
- The agents receive `${CLAUDE_PLUGIN_ROOT}/references` as `references:`.

**Usage:** `/tce:work [PREFIX]-XXXX` (ticket required; run `/tce:intent` first).

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

---

## Invariants

1. **One agent per step, in the foreground.** Dispatch with "Use the
   tce:<agent> agent" and wait for its result: `tce:researcher`,
   `tce:planner`, `tce:plan-challenger`, `tce:implementer`, `tce:verifier`.
2. **Artifacts travel by path, never by contents.** Payloads are the
   `key: value` lines in `work-dispatch.md`; you never paste a document into a
   prompt and never read the research's or plan's body. You read only what the
   position table names, the agents' returns, and the ticket.
3. **You never edit code, the research or the plan's body.** Your only writes
   are the plan's `## Implementation Closeout`, the ticks on Manual items the
   human confirmed (Step 12), the ticket's done transition and the delivery.
4. **Only `needs decision` and `blocked` reach the human**, plus the planning
   questions, the brief and the closing confirmation of items left for them.
   `done with concerns` never stops the run.
5. **Ask through AskUserQuestion**, so the whole run stays in one turn — the
   scripts above are granted for this turn only.
6. **The position is re-derived from disk** after every step, never
   remembered.

## Step 0 — Preflight

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/work.sh" preflight`. Unless both
`foreground:` and `timeout:` say `ok`, refuse and stop:

```
/tce:work needs foreground agents and a long Bash timeout. Quit Claude Code,
then start it again with:

  export CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1
  export BASH_DEFAULT_TIMEOUT_MS=600000
```

## Step 1 — Ticket

Resolve the canonical ticket ID as `tickets.md` describes; with no argument, ask
for one and stop. Read the ticket now, fully, with `tickets.md`'s read mechanism
— even if it appeared earlier in this conversation.

## Step 2 — Branch

Read the `## Branch convention` section of `profile.md`. If it is absent or says
**Current branch**, skip this step entirely and print nothing. If it says
**Branch per ticket**, resolve the branch name from the recorded pattern (a
`<slug>` element is a short kebab-case slug of the ticket title) and run
`"${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" switch <branch>`: `switched` or
`already` → continue (one line naming the branch); `missing` → refuse as in
Step 3 point 2 — `/tce:intent` cuts the ticket branch before it writes the
intent, so a missing branch means there is no intent yet, and `/tce:work` never
cuts one itself; `dirty` → ask the user to commit or stash, then re-run;
`blocked` → report the `detail:` line and stop.

## Step 3 — Intent and parent

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-XXXX` and
   `"${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh" [PREFIX]-XXXX`.
2. If `stage.sh`'s `intent:` line is empty, refuse and stop:
   "No intent for [PREFIX]-XXXX — run `/tce:intent [PREFIX]-XXXX` first."
3. If the ticket has a parent (per `tickets.md`'s "Parent / epic tickets"), run
   `ticket.sh` for the parent too; its ticket, research and plan paths become
   the `parent:` field.
4. A ticket that involves a non-trivial UX change gets no design exploration
   inside this flow: the planner asks whether to stop for
   `/tce:design_explore`.

## Step 4 — Position

Read `${CLAUDE_PLUGIN_ROOT}/references/work-dispatch.md` **now — in full**, and
take the first row of its position table that matches. Print one line:
"[PREFIX]-XXXX: continuing at <step> (phases done: <k>/<N>)" — leave out the
parenthesis before a plan exists. Then run the steps below from there, in
order, re-running `stage.sh` (and the table) after each.

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
   print its `Understood:` and `Approach:` lines as the intro, then ask every
   question through AskUserQuestion — one decision per question, its options
   exactly as returned (recommended first), at most four per call. If the
   human chose to stop for design exploration, stop: "Run
   `/tce:design_explore [PREFIX]-XXXX`, then `/tce:work [PREFIX]-XXXX`
   again." Otherwise resume the planner with `mode: write` and the answers
   verbatim (`answers: none` when there were none). A `needs decision` from
   `write` is another round of the same.
3. Dispatch `tce:plan-challenger` with the planner's brief. On `needs
   decision`, resume the planner with `mode: challenge-fix` and the failing
   lines, then challenge again — at most 3 rounds; then stop with
   `needs decision`. Keep its human items.
4. Print the brief exactly as the planner returned it, then the challenger's
   human items under "Challenger notes:". If "Decisions for you" is not
   `None.`, ask those first, as in point 2, resume the planner with
   `mode: revise` and `push-back:` carrying each question's header and the
   answer, re-run the challenger, and print the delta. Then ask:

   Question: "Approve the plan?" — header: "Plan", options:

   1. **Approve (Recommended)** — Implementation starts now and runs to the
      dossier without further questions unless something blocks.
   2. **Stop here** — The plan stays committed; re-run /tce:work to come back
      to this approval.

   A free-text answer is a push-back: resume the planner with `mode: revise`
   and the text verbatim, re-run the challenger, print the delta, and ask
   again. When this step is reached from the position table with a plan
   already written, dispatch the planner with `mode: brief` first.

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
   that, the parent of
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
  `gh pr create --base <base> --head <branch> --title "[PREFIX]-XXXX: <ticket title>" --body-file <dossier-path>`.
  If a command fails, stop as `blocked` with its last output line. The merge
  reference is the pull request's URL. tce never merges.

## Step 11 — Closeout and summary

1. Append to the plan:

   ```markdown
   ## Implementation Closeout

   - **Plan-compliance gate**: [the verifier's verify summary, one line]
   - **Manual verification**: [verified by agent | pending: <items for you to check>]
   - **Merge reference**: [from Step 10]
   - **Ticket**: [PREFIX]-XXXX → Done   (or: → Done once the items above are checked)
   ```

2. If nothing is left for the human to check, make the done transition per
   `tickets.md`'s "Status / completion" (for tmt: `**Status:** Done`); if the
   policy says tce does not transition, say which transition is due.
3. Commit the plan and the ticket with the `/tce:commit` command; under Pull
   request delivery, `git push` again.
4. Print the summary: under Direct, the dossier's text; under Pull request,
   the URL and the dossier's counted-facts line. Add the config-drift line if
   Step 5 kept one. If items are pending, continue with Step 12.

## Step 12 — Items for you to check

Reached from Step 11, or from the position table when the Closeout says
`pending:`. Restate every pending item in full — what to run or do and what
pass looks like (from the plan's `## Verification`) — then ask:

Question: "Have you checked the items above?" — header: "Checked", options:

1. **All pass** — I tick them in the plan, mark the ticket done and commit.
2. **Not yet** — Nothing changes; re-run /tce:work when you have checked them.

- **All pass:** tick each pending Manual item in the plan, appending
  ` — confirmed by user YYYY-MM-DD`; set the Closeout's Manual verification
  line to `confirmed by user YYYY-MM-DD` and its Ticket line to `→ Done`; make
  the done transition per `tickets.md`; commit with `/tce:commit` (and
  `git push` under Pull request delivery).
- **Not yet:** stop.
- **A free-text answer** reports a failure: set the Closeout's Manual
  verification line to `failed: <the human's text, one line>` and stop with a
  `needs decision` that names it. Fixing it is the human's call — a new
  ticket, or a fix followed by a re-run.
