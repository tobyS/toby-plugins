---
date: 2026-09-09
git_commit: 8a23f53ea4618c1ccb031cf45716ffe4f83ec64e
branch: main
repository: git@github.com:tobyS/toby-plugins.git
topic: "TP-0033: /tce:list — ticket listing with tce workflow stage"
tags: [research, codebase, tce, commands, tickets-adapter, scripts, plan-parsing]
status: complete
last_updated: 2026-09-10
---

# Research: TP-0033 — `/tce:list`, ticket listing with tce workflow stage

**Date**: 2026-09-09
**Git Commit**: 8a23f53ea4618c1ccb031cf45716ffe4f83ec64e
**Branch**: main
**Repository**: git@github.com:tobyS/toby-plugins.git

## Research Question

How should `/tce:list` be built — a command that prints one table row per ticket
carrying the backend status plus the tce stage (research doc / plan doc /
implementation progress), with epic nesting and a backend-conditional Priority
column — while staying ticket-system-agnostic? Specifically, the ticket's own
deferred questions: shipped script or pure prompt; whether plan phase completion
is reliably parseable; whether `ticket.sh` needs a bulk mode; what the new
"Listing tickets" adapter section looks like; how an epic rolls up; and whether
the free-form prompt argument needs a vocabulary.

## Summary

The feature splits cleanly along a seam the plugin already has. **Enumeration is
backend-specific** and must come from `.claude/tce/tickets.md` (a GitHub backend
enumerates with `gh issue list`, tmt with a directory glob) — no shipped script
can do it without hardcoding tmt's layout. **Stage derivation is
backend-independent**: research and plan documents always live in `thoughts/`
under a filename carrying the canonical ticket ID, and implementation progress
always lives inside the plan document. That half is fiddly, deterministic text
parsing — exactly what a shipped script is for, and the `baseline.sh` /
`branch.sh` contract is the established shape for one.

The single most consequential finding is that **implementation progress is only
machine-derivable for plans written after TP-0023** (2026-07-10, when the
`.status.md` sidecar was merged into the plan's `### Implementation log`). In
this repo that is **7 of 28 plans**; 20 rely on a legacy `.status.md` sidecar
with no standardized format, and 1 (TP-0006) has neither. A parser also has to
strip fenced code blocks first — this repo's plans quote tce's own markdown, so
column-0 `## Phase 1:` and `## Implementation Closeout` headings appear *inside*
fences and produce confirmed false positives. And phase headings vary in level
(`##` vs `###`), separator (`:` vs em dash) and decoration (a trailing `✅ DONE`).

Checkbox ratios are a **trap** as a completion proxy: 9 fully-implemented plans
in this repo have zero ticked boxes, while completed plans legitimately retain
unticked Manual Verification items (they are only ticked on explicit human
confirmation). Progress must come from log-block statuses, never checkboxes.

The adapter template has a well-defined register for a new section, `/tce:init`
and `/tce:refresh` have exact places that must learn it, and the classification,
README and version-bump obligations in the acceptance criteria all map to
concrete lines. Nothing in the ticket is blocked by a missing mechanism.

## Detailed Findings

### The existing lister (`/tmt:list`) — prior art and its ceiling

`plugins/tmt/commands/list.md` is 22 lines: a description-only frontmatter, one
bash invocation, four presentation bullets. All work is in
`plugins/tmt/scripts/open_tickets.sh`, which enumerates
`${TICKET_PREFIX}-*.md` under `thoughts/shared/tickets/`, filters status to the
two literals `Open` / `In Progress`, extracts title and `**Estimated
Complexity:**`, globs `thoughts/shared/research` and `thoughts/shared/plans` for
a per-ticket match, and prints a four-line block per ticket.

Its structural ceilings, each of which TP-0033 names:

- Status filtering is a hardcoded positive allowlist (`open_tickets.sh:47-49`),
  not "not terminal", and it does **not** consume `tmt_valid_statuses()` from
  `lib.sh:40-42` even though that function is documented as the single source of
  truth for the enum.
- Document detection is presence-only (`open_tickets.sh:68-69`, `head -1`) — the
  plan file is never opened, so there is **no notion of implementation
  progress**. This is precisely the gap TP-0033 exists to fill.
- Output uses `✅` / `❌` (`open_tickets.sh:73-81`) — the emoji-presentation
  glyphs TP-0033 rules out.
- It is tmt-owned and tmt-specific by design; `list.md:14-17` reaches toward tce
  only in prose ("if the project doesn't use tce, omit those lines"), never by a
  cross-plugin reference. That one-directional courtesy is the correct boundary
  and TP-0033 explicitly leaves it alone.

### The shipped-script contract (`baseline.sh`, `branch.sh`)

These two establish the current pattern, and they agree on five points:

- **Positional arguments, mode first where there are modes**
  (`branch.sh:7-9`: `create` / `switch` / `check`), with a `Usage:` block
  carrying a concrete example and `exit 1` on misuse (`baseline.sh:30-34`).
- **Stdout is a fixed number of aligned `key: value` lines emitted by a
  `report()` helper that exits** (`baseline.sh:46-51`, `branch.sh:81-86`).
- **The value vocabulary is a closed enumeration declared in the header
  comment** — `source: recorded | introducing | none` (`baseline.sh:18`);
  `branch.sh:28-31` lists a per-mode enum. The last line is always free prose
  intended to be shown to the user.
- **Every reported outcome exits 0**; only usage errors and "not a git
  repository" exit 1 (`branch.sh:34-35`). This is the sharpest divergence from
  `open_tickets.sh`, where "No tickets found" exits 1.
- **Semantics live in the script, policy decisions live in the command.**
  `branch.sh:4-5` states it outright: "the calling command decides whether the
  convention applies and resolves the branch name; this script does the git." It
  never reads `profile.md`.

Every invoking command pre-authorizes the script in frontmatter, one
`Bash("${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh":*)` entry each
(`research.md:4`, `plan.md:4`, `implement.md:4`, `review.md:5`, `commit.md:3`,
`work.md:5`, `quickfix.md:5`).

### The hard constraint on any new tce script

`plugins/tce/scripts/lib.sh` is 13 lines and exposes exactly one function,
`tce_project_root()` (`lib.sh:11-13`). There is deliberately **no tce config
reader and no prefix helper** — `CLAUDE.md` states tce has no machine-readable
config file and forbids creating `.claude/tce/config`. Everything
project-specific reaches tce by the *model* reading `profile.md` /
`tickets.md` at runtime.

So a new tce script can locate the project root but **cannot ask for a ticket
prefix, a status policy, or a tickets directory**. Any such value must arrive as
a command-line argument that the command resolved from the adapter — which is
exactly the `branch.sh` division of labour, and is what keeps a script from
becoming a tmt hardcode.

### `ticket.sh` and the bulk question

`plugins/tce/scripts/ticket.sh` is 33 lines whose entire payload is line 33:

```bash
find "$THOUGHTS_DIR" -type f -name "*${TICKET}*" | sort
```

It takes exactly one ID (`ticket.sh:25`, `TICKET="$1"`; extra arguments are
ignored), outputs bare absolute paths one per line with no keys and no grouping,
and exits 0 with empty stdout when nothing matches. Its eight call sites are all
single-ticket (`research.md:134`, `:144`, `plan.md:82`, `implement.md:62`,
`:75`, `review.md:133`, `work.md:100`).

Two properties matter for a backlog-wide listing:

- **No bulk mode and no grouping.** Calling it once per ticket works but yields N
  Bash round-trips with no way to tell which output line belongs to which ID
  other than re-matching the ID in the path.
- **A substring match**, so `TP-0100` also matches `TP-0100a-…` files — the
  opposite of `open_tickets.sh`'s `*ID-*` / `*ID.*` pair. For a lister that
  nests sub-tickets under parents, that over-match is a live correctness
  concern: an epic would inherit its children's documents.

### How a plan encodes phases and completion

**The spec.** `plugins/tce/references/plan-document-template.md:55` prescribes
`## Phase 1: [Descriptive Name]`, with `### Overview` → `### Changes Required:`
→ `### Success Criteria:` inside and a `---` separator. Critically,
`plan-document-template.md:168-178` **forbids authoring any progress markers**:
"A plan is always authored without them — never include log blocks, a closeout
section, or pre-ticked success-criteria checkboxes when writing a plan." So a
freshly planned, not-yet-started plan is by contract indistinguishable from a
zero-phases-done plan except by the *absence* of log blocks.

`implement.md:104-106` makes the plan "the single record of implementation
progress", with the verbatim block format at `implement.md:110-120`:

```markdown
### Implementation log

- **Status**: ✅ Complete | ⚠️ Partial | ❌ Blocked
- **Base commit**: `<hash>` (first phase's log only …)
- **Commit**: `abc1234` <commit subject …>
- **Did**: …
- **Issues**: …
- **Verification**: …
```

Full completion is a **two-signal test** (`implement.md:142`): every phase's log
says `✅ Complete` **and** every success-criteria checkbox is ticked. Legacy
fallback is Rule 4 (`implement.md:144`): a sibling `<basename>.status.md` from
older tce versions, read-only, never created or written.

**The corpus.** 28 plans in `thoughts/shared/plans/` split into three eras:

| Era | Plans | Progress mechanism |
|---|---|---|
| TP-0001 … TP-0022 (minus TP-0006) | 20 | sibling `*.status.md` |
| TP-0006 | 1 | **nothing** |
| TP-0023 … TP-0031 | 7 | in-plan `### Implementation log` |

Within the modern era the format is disciplined: `- **Status**:` is always the
block's third line and always present; `- **Base commit**:` appears in the first
phase's log only; log blocks always sit inside their own phase, so positional
assignment works. Two blemishes: TP-0024's status value wraps across three lines
(`…-TP-0024-….md:154-156`), and one `**Commit**` hash was never filled
(`…-TP-0025-….md:1034`).

Legacy `.status.md` files are **not** standardized — some carry
`- **Status**: ✅ Complete` per phase
(`…-TP-0022-….status.md:1-8`), others encode completion only as a heading suffix
`## Phase 1 — … — DONE` (`…-TP-0012-….status.md:5`), and heading levels drift
between a plan and its own status file (`…-TP-0020-….md:93` uses `##` while
`…-TP-0020-….status.md:20` uses `###`).

### Parser failure modes (all confirmed against real files, not hypothetical)

1. **Fenced-code false positives.** `…-TP-0030-….md:346` is a column-0
   `## Implementation Closeout` inside a ```` ```markdown ```` fence opened at
   `:345`; the real closeout is at `:646`. `…-TP-0021-….md:22` and `:155` are
   `### Phase 1b:` headings inside fences while the real phases are at `:140`
   and `:202`. **Fences must be stripped before matching headings.**
2. **Heading-level and separator variance.** A regex anchored on `^## Phase (\d+)`
   reports **zero phases** for TP-0005 and TP-0014 (both use `###`), and must
   tolerate `:` and `—` plus a trailing ` ✅ DONE` decoration (TP-0008). The
   corpus supports `^#{2,3}\s+Phase\s+(\d+)\s*[:—-]`.
3. **Checkboxes are a bad proxy.** 518 checkboxes across the corpus, 340 ticked —
   but **9 fully-implemented plans have 0 ticked boxes** (TP-0004, 0005, 0006,
   0007, 0009, 0011, 0013, 0014, 0016), and TP-0031 is 5/5 phases complete with 8
   of 31 boxes unticked because Manual items await human confirmation
   (`implement.md:148`). Never derive `n/m` from checkboxes.
4. **Closeout presence is one-directional.** TP-0031 is 5/5 complete with **no**
   `## Implementation Closeout`. Its presence corroborates done; its absence
   implies nothing.
5. **Plan frontmatter is useless as a join key or status source.** Only 10 of 28
   plans have frontmatter at all, all in the TP-0004…TP-0015 window, and its
   `status:` is stale (TP-0006 says `status: ready` for work that shipped).
   There is no `phases:` count and no `branch:` field in any plan.
6. **Join on the ID segment of the filename, never the date.** Both document
   kinds are named `YYYY-MM-DD-<TICKET-ID>-<slug>.md` and a ticket's research and
   plan dates differ (TP-0031: research `2026-09-03`, plan `2026-09-05`).

Applying the derivation the data supports — strip fences; `m` = phase-heading
count; `n` = log blocks whose `- **Status**:` line shows `✅`/`Complete`; else
fall back to `.status.md` as *approximate*; else report unknown — yields exact
results for 7 plans, heuristic for 20, and an honest unknown for 1 in this repo.

### The `tickets.md` adapter — register and the wiring a new section drags in

The template (`plugins/tce/templates/tce/tickets.md`, 91 lines) has eight
sections: `## System` (:8), `## Canonical ticket ID` (:13), `## Reading a ticket`
(:20), `## Parent / epic tickets` (:26), `## Creating a ticket` (:32),
`## Ticket title & body layout` (:42), `## Status / completion` (:51),
`## What tce needs from a ticket` (:64).

The marking convention is exact: **bracketed guidance = backend-specific, to be
replaced at fill time; unbracketed prose plus an HTML `Backend-independent`
comment = ships as-is** (`:66-67`). Backend sections are nothing but a
square-bracketed instruction block in imperative register ("Name the…", "State
how to…", "Give the concrete action for…"), with generic examples spanning a file
backend *and* an issue tracker, and a **sentinel-value escape hatch** for
inapplicable backends (`"none"` at `:29-30`, `"not allowed"` at `:36`, `"do not
transition — remind the user instead"` at `:61-62`). That sentinel device is the
natural way to express "this backend has no priority".

Note `## Status / completion` (`:53-62`) describes lifecycle *moments*
(start/complete/reject) and transition actions — it does **not** declare a
terminal-status set a lister could read. TP-0033's first acceptance criterion
("not in a terminal status … from the project's status policy") therefore needs
either a new declaration or a derivation from that section.

A profile-side precedent exists for a richer shape: `profile.md`'s
`## Branch convention` (`templates/tce/profile.md:70-97`, TP-0031) pairs an
unbracketed intro paragraph naming who fills it and who reads it with a bracketed
menu of mutually exclusive options, each carrying bolded sub-fields and an
explicit absent-section equivalence ("The default — identical to leaving this
section out.").

**The wiring a new section must join**, with exact anchors:

- `plugins/tce/commands/init.md:402-406` — the Phase 4 step-2 enumeration of
  backend sections, plus a clause in each of the three per-system guidance
  bullets (`:407-416` tmt, `:417-424` GitHub, `:425-429` Jira/Linear/custom).
- `plugins/tce/commands/init.md:531-537` — the Idempotency upgrade list. All
  three existing bullets are `profile.md`-only; this would be the first
  `tickets.md` bullet. Style: "A `tickets.md` without X … needs …", naming the
  insertion anchor and the version that introduced it.
- `plugins/tce/commands/refresh.md:27-35` (scope), `:75-80` (Phase 1 item 4),
  `:98-108` (the factual vs. hand-authored classification), `:116-118`
  (high-confidence drift triggers). A "Listing tickets" section describing
  *mechanism* is factual; if it also carries a priority *policy* it straddles.
- `plugins/tce/README.md:260-265` — the "Ticket system" bullet enumerating what
  the adapter covers.
- The version marker lives **only** in `profile.md` (`refresh.md:141-147`);
  `tickets.md` carries none, so a `tickets.md` change is reflected through the
  profile's marker.

### Command authoring: frontmatter, preamble, classification

The `disable-model-invocation` split (`CLAUDE.md`, TP-0017) is: delegation
targets (`ticket`, `research`, `plan`, `implement`, `commit`) never carry it;
user-only top-level commands with no inbound delegation do (`init`, `refresh`,
`work`, `quickfix`, `review`, `discuss`, `design_explore`, plus
`implement_eco`). `/tce:list` has no inbound delegation edge, which places it in
the second set by the letter of the rule — but note the whole tmt set is
unflagged, including `/tmt:list`, and a read-only lister is the archetypal thing
a user asks for in prose.

Frontmatter field order in the newest files is `description` → `argument-hint` →
(`model`) → `disable-model-invocation` → `allowed-tools` (`review.md:1-6`,
`work.md:1-6`).

The `## Project context` preamble has four established variants; the
ticket-system-precondition form is `ticket.md:20-30` ("If the file is missing,
tell the user to run `/tce:init` and stop"), which matches TP-0033's acceptance
criterion for a missing `tickets.md` exactly.

For free-form arguments, `review.md:61-107` is the fullest example (detect,
route, and a no-input response block) and `tmt/list.md:20-21` the closest
analogue ("filter the script's output accordingly when presenting it"). **No
existing command performs the "state in one line how the prompt was interpreted"
echo** that TP-0033 requires — that is new copy, not a pattern to mirror.

The README catalog (`plugins/tce/README.md:196-238`) is four titled tables with a
`| Command | Purpose |` header (Core workflow / Shortcuts / Helpers /
Maintenance); a lister belongs under **Helpers**. The root `README.md` lists no
individual commands and needs no change. Note `/tce:implement_eco` exists but has
no row in any table — an existing omission, not a precedent to copy.

### Output-format facts

The ticket's Notes record that the first example tables misrendered because `✅`
is an emoji-presentation character occupying two terminal columns while the
padding counted it as one.

**Updated after the fact:** the web lookup stalled and was abandoned while this
document was being written, then returned during implementation. Its findings
supersede the paragraph that stood here, in three ways.

**1. The renderer does lay tables out — confirmed.** Anthropic's accessibility
documentation describes screen-reader mode as making "tables in Claude's replies
read as `Header: value` sentences instead of **a box-character grid**", which
documents the default terminal rendering by contrast. Changelog entries about
per-cell borders, wrapped continuation lines and a "narrow-terminal stacked
layout" confirm the renderer computes its own column widths. So emitting a real
markdown table and not hand-padding is correct.

**2. A wide table does not stay a table.** Issue
[#44696](https://github.com/anthropics/claude-code/issues/44696) reports that a
table exceeding the terminal width is collapsed into stacked key/value cards, one
per row — triggered by roughly "6+ columns of moderate width". The ticket's locked
table is 8 columns (7 without Priority). The same flattening occurs in
screen-reader mode and in `claude -p` output. This is a genuine risk to the
command's purpose and was raised with the user, who chose to keep the locked
columns and truncate titles.

**3. The glyph analysis above was wrong in one place.** Per UAX #11 and
`EastAsianWidth.txt`: `✅` U+2705 is **Wide** (`Emoji_Presentation`, 2 columns) —
as stated. But `✓` U+2713 is **Neutral**, not Ambiguous: it is 1 column
everywhere, the safest of the set. `–` U+2013 and `└`/`─` U+2514/U+2500 *are*
**Ambiguous** — 1 column in a Western-locale terminal but 2 under an East-Asian
locale or a terminal configured "ambiguous = wide". The user chose to keep them
as the ticket locks them, which is correct for the realistic case. Issue
[#69093](https://github.com/anthropics/claude-code/issues/69093) shows the
renderer's bundled width table can itself disagree with the emulator's, which is
why the emoji-presentation ban matters most.

## Impact Analysis

The ticket reuses two shared artifacts for a new purpose.

### Existing usages found

- `plugins/tce/scripts/ticket.sh` — 8 call sites, all single-ticket:
  `research.md:134` and `:144` (parent), `plan.md:82`, `implement.md:62` and
  `:75`, `review.md:133`, `work.md:100`.
- `plugins/tce/templates/tce/tickets.md` — sections are cited by heading string
  at `quickfix.md:20` and `:106`, `implement.md:332`, `research.md:141`,
  `plan.md:89`, `research.md:156`; adapter mechanisms are enumerated in drift
  prose at `research.md:272-282` and mirrored in `work.md:113`,
  `quickfix.md:279`.

### Current contract

- `ticket.sh`: input one canonical ticket ID; output bare absolute paths of every
  `thoughts/` file whose name contains it, sorted; exit 0 even when empty.
- `tickets.md`: eight named sections, read by heading name at runtime; backend
  sections bracketed in the template, one section marked backend-independent.

### Adaptation requirements

- `ticket.sh` — a bulk mode would need to preserve the existing single-ID
  behaviour byte-for-byte (8 callers depend on the bare-path output), so any
  addition must be a new mode or a new script rather than a changed default. The
  substring over-match (`*ID*` matching `ID` + `IDa`) would need tightening for
  epic correctness, which **is** a behaviour change to the existing contract and
  should be assessed against those 8 callers.
- `tickets.md` — a ninth section is additive for new projects, but every existing
  consuming project has an eight-section file, hence the init Idempotency bullet.

### Backward compatibility options

- **Option A — a new script** (`list-stage.sh` or similar) leaving `ticket.sh`
  untouched. No risk to 8 existing callers; some duplicated globbing.
- **Option B — a mode added to `ticket.sh`** (`ticket.sh bulk <id>…`). One script
  to maintain; requires the mode-first argument shape of `branch.sh` and careful
  preservation of the bare-ID default.

## Code References

- `plugins/tmt/commands/list.md:1-21` — the whole existing lister command
- `plugins/tmt/scripts/open_tickets.sh:33` — enumeration glob; `:47-49` hardcoded
  status allowlist; `:68-69` document detection; `:73-81` the `✅`/`❌` output
- `plugins/tmt/scripts/lib.sh:22-35` — `tmt_ticket_prefix` with legacy fallback;
  `:40-42` `tmt_valid_statuses`
- `plugins/tce/scripts/lib.sh:11-13` — the only tce helper, `tce_project_root`
- `plugins/tce/scripts/ticket.sh:25`, `:33` — single-ID argument and the find
- `plugins/tce/scripts/baseline.sh:16-19`, `:46-51` — the three-line report
  contract; `:39-44` the project-root + git guard
- `plugins/tce/scripts/branch.sh:4-5` — the script/command division of labour;
  `:26-32` report helper; `:28-31` per-mode result enums; `:34-35` exit policy
- `plugins/tce/references/plan-document-template.md:55` — phase heading;
  `:72-88` success criteria; `:168-178` the no-progress-markers rule
- `plugins/tce/commands/implement.md:104-106`, `:110-120` — log block spec;
  `:142` two-signal completion; `:144` legacy `.status.md`; `:148` manual ticks
- `plugins/tce/templates/tce/tickets.md:8-62` — the eight sections; `:66-67` the
  backend-independent marker
- `plugins/tce/templates/tce/profile.md:70-97` — the TP-0031 section shape
- `plugins/tce/commands/init.md:402-429` — Phase 4 `tickets.md` fill;
  `:531-537` the Idempotency upgrade list
- `plugins/tce/commands/refresh.md:27-35`, `:75-80`, `:98-108`, `:116-118` — the
  four places refresh classifies adapter sections
- `plugins/tce/commands/review.md:61-107` — fullest free-form-argument handling
- `plugins/tce/commands/ticket.md:20-30` — the stop-if-`tickets.md`-missing form
- `plugins/tce/README.md:196-238` — the command catalog; `:260-265` the adapter
  bullet
- `thoughts/shared/plans/2026-09-02-TP-0030-drift-check-rewritten-history.md:345-346`
  — a confirmed in-fence heading false positive
- `thoughts/shared/plans/2026-07-12-TP-0024-eco-implement-wrapper-sonnet.md:154-156`
  — a wrapped `**Status**` value

## Architecture Documentation

Three repo rules govern this work and are already recorded in `CLAUDE.md`:

- **Core design rule** — no ticket-system literals in tce commands; per-project
  data lives in `.claude/tce/`. A shipped script may not read that config, so
  policy flows script-ward only as arguments.
- **`/tce:refresh` tracks `/tce:init`** — a new adapter section must be learned by
  both in the same commit, and classified factual vs. hand-authored.
- **TP-0017 invocation control** — a new command must be classified and the
  `CLAUDE.md` lists updated.

Note also that the AskUserQuestion guidelines block is duplicated
byte-identically across ten files; a new command with a dialog site would make it
eleven. `/tce:list` as specified has no dialog site, so this likely does not
apply — worth confirming during planning.

## Historical Context (from thoughts/)

- `thoughts/shared/tickets/TP-0023-merge-status-file-into-plan.md` and its plan —
  why `.status.md` was retired into the plan's log; the plan records that all 20
  existing sidecars belong to Done tickets.
- `thoughts/shared/research/2026-09-03-TP-0031-declarable-branch-convention.md`
  and `2026-09-02-TP-0030-drift-check-rewritten-history.md` — the two most recent
  "shipped script + command" features; the model for `branch.sh`/`baseline.sh`.
- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md` —
  the `disable-model-invocation` classification reasoning.
- `thoughts/shared/discussions/2026-06-15-tce-ticket-authoring-vs-tmt-envelope.md`
  — the adapter-contract seam between tce payload and tmt envelope.
- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — the
  independent review that produced the "asserted rather than checked invariant"
  framing cited in `CLAUDE.md`.

## Related Research

- `thoughts/shared/research/2026-09-03-TP-0031-declarable-branch-convention.md`
- `thoughts/shared/research/2026-09-02-TP-0030-drift-check-rewritten-history.md`
- `thoughts/shared/research/2026-07-10-TP-0023-merge-status-file-into-plan.md`
- `thoughts/shared/research/2026-06-15-TP-0007-tce-ticket-authoring-tmt-envelope-split.md`

## Open Questions

1. **Script/prompt split.** Research supports a hybrid: enumeration from the
   adapter (backend-specific, prompt-driven), stage derivation in a shipped
   script (backend-independent, fiddly parsing). To confirm, plus whether the
   script is new or a mode on `ticket.sh`.
2. **What the Implementation cell shows when progress is not parseable** — 21 of
   28 plans in this very repo. Options range from an honest unknown marker to
   reading the legacy `.status.md` heuristically.
3. **Epic roll-up when the parent carries its own plan *and* sub-tickets.** The
   ticket fixes the roll-up in the Implementation cell but does not say what
   happens to the parent's own phase progress.
4. **`disable-model-invocation` for `/tce:list`.** The letter of TP-0017 says
   flag it; its being read-only and prose-requested argues the other way.
5. **Whether priority rides inside the "Listing tickets" section or gets its own
   declaration**, and whether the terminal-status set needs declaring separately
   from `## Status / completion`.
6. **Prompt-argument vocabulary** — research found no existing echo-back pattern
   to mirror, so this is new copy either way; natural-language interpretation plus
   the one-line echo appears sufficient.

## tce Config Drift

None found. `profile.md`'s stack, commands and code map match the repo (all three
plugins present, scripts where recorded, `claude plugin validate` still the test
command), and the `tickets.md` adapter resolves (`.claude/tmt/config` present,
ticket files match `TP-NNNN`).
