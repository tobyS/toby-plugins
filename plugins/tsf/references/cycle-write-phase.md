<!--
Runtime reference for the tsf software factory. Read by /tsf:cycle at Step 7
(Write), and at Step 4 when prepare fails — always in full, even if already read
earlier in the session. Never copied into consuming projects.

Changes to this file are command-contract changes: the CLAUDE.md rule "tsf: the
dispatcher owns every GitHub write" applies — the subcommands and result:
vocabularies used below belong to plugins/tsf/scripts/gh-write.sh and push.sh,
so a change on either side updates the other, plus plugins/tsf/commands/cycle.md,
spec.md and init.md, in the same commit.

Contents:
1. The write sequence
2. Parking on a failed write
3. Parks without an agent result
4. Prepare failed
-->

# The write sequence

Performed once per cycle, in this order, for the step's validated result. Every
script call below takes `--repo <owner/repo> --as factory --credential <source>`
(push.sh takes only `--credential`); `<plugin root>` is the value `cycle.md`
names. Check each `result:` line before the next call.

The order is deliberate (DESIGN.md §5.1 step 6): the journal is committed and
pushed **before** the comment and the label, so the comment's journal link
resolves and a board that shows the new label always has the entry behind it.

1. **Journal entry.** Read `<plugin root>/references/templates/journal-entry.md`
   **now — in full**. Append to `thoughts/factory/GH-<n>/journal.md` (create it
   with the line `# Journal: GH-<n>` and a blank line when absent):
   `## Cycle <now> — step: <step>` followed by the `tsf-journal` block's lines,
   verbatim. `<now>` is the preflight's `now:`.
2. **Commit** — `git add thoughts/factory/GH-<n>/journal.md`, then
   `git commit -m "<message>"` with one single-line message in the project's
   commit convention, scope `GH-<n>` (e.g. `docs(GH-<n>): journal research`).
   Stage nothing else: the agent committed its own artifact.
3. **Push** — `<plugin root>/scripts/push.sh --branch <branch> --credential
   <source>`. Expect `pushed` or `up-to-date`. Anything else → the push
   handling at the end of "Prepare failed" below (the journal cannot reach
   GitHub).
4. **Marker block** — `<plugin root>/scripts/gh-write.sh marker … --issue <n>
   --ticket GH-<n> --branch <branch> --journal`. Expect `ok`.
5. **Comment** — write the `tsf-comment` block's content (harness escaping
   undone) to a file in your scratchpad directory, then
   `<plugin root>/scripts/gh-write.sh comment … --issue <n> --body-file <file>`.
   Expect `ok`; keep `id:` for the report.
6. **Label** — `<plugin root>/scripts/gh-write.sh labels … --issue <n> --set
   <next-label>`. Expect `ok`; keep `previous:` for the report.

A **correction** of a stale factory-side label (cycle-dispatch.md) happened
before the dispatch; it is not repeated here.

# Parking on a failed write

A write in steps 4–6 that reports anything other than its expected result
(`rejected`, `denied`, `failed`, `mismatch`, `no-credential`) parks the ticket.
Do not retry by hand — the scripts already retried a transport error once.

1. Append a second journal entry, the failed-write shape of `journal-entry.md`:
   outcome `write failed: <subcommand> — <detail>`, `Label: tsf:needs-human`,
   `Next step` unchanged from the step's result. Commit it like step 2 and push
   like step 3 (best effort).
2. `gh-write.sh labels … --set tsf:needs-human` (best effort — it may fail for
   the same reason).
3. Report the failed operation and its `detail:` prominently.

# Parks without an agent result

A state mismatch (cycle-dispatch.md) or a twice-invalid agent return
(result-block.md) has no result block. Write it with the same sequence:

1. Journal entry — the matching dispatcher-only shape of `journal-entry.md`.
2. Commit, 3. push, 4. marker block — as above.
5. Comment — one line of your own: `**tsf · GH-<n>** — parked for a human:
   <the outcome line>. Details in the [journal](<journal link>).` The journal
   link is `https://github.com/<owner/repo>/blob/<branch>/thoughts/factory/GH-<n>/journal.md`.
6. Label `tsf:needs-human`.

A failure in 4–6 is reported; there is nothing further to park into.

# Prepare failed

The ticket branch could not be checked out, so no journal can be written or
pushed for it. Park it on GitHub only, so the next cycle does not pick it again:

1. Comment, as in "Parks without an agent result" step 5 but without the journal
   link: `**tsf · GH-<n>** — parked for a human: the project's prepare script
   failed for branch <branch>: <its last output line>.`
2. `gh-write.sh labels … --set tsf:needs-human`.
3. Report it; if the same prepare failure is likely environment-wide (it names
   the remote, the network, the checkout itself), say so.

When the human re-queues the ticket, the journal on the branch (if any) still
says where it stood.

Also use this section when a push in step 3 fails: the journal entry exists only
locally and the next prepare discards it, so comment with the push's `detail:`
line instead of a journal link, set `tsf:needs-human`, and report it.
