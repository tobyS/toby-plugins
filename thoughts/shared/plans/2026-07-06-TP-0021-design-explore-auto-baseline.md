# TP-0021: design_explore Auto-Baseline Capture Implementation Plan

## Overview

Rewrite `/tce:design_explore` Phase 1b so it tries to capture the visual
baseline (desktop + mobile screenshots of existing pages) itself using
whatever browser automation tooling is available in the session, asking the
user only for what it can't determine itself (app URL, dev-server startup,
auth), and falling back to the current manual screenshot request when no
tooling is available, capture fails, or the user prefers manual. Adds an
optional `## Dev environment` field to `.claude/tce/profile.md` (per the
user's decision at the question checkpoint) so a dev-server URL, once
provided, is remembered across sessions instead of asked every time.

## Current State Analysis

`plugins/tce/commands/design_explore.md` Phase 1b (`design_explore.md:63-73`)
unconditionally asks the user for screenshots — there is no branch, no
capability check, and no automated path:

```markdown
### Phase 1b: Visual Baseline — See the Existing UI

**Before proposing any designs, you MUST see what the existing related pages actually look like rendered.** Code research alone is not sufficient — CSS classes can combine in unexpected ways, and you need a visual reference to match the design language faithfully.

Ask the user to provide screenshots of the relevant existing pages (desktop and mobile):

> I need to see the current [page name] on desktop and mobile to match the design language accurately.
>
> Could you share screenshots of the desktop and mobile views?

**Only proceed once you have a visual reference.** Do not skip this step. Code research supplements visual verification — it does not replace it.
```

Phase 1c (`design_explore.md:75-116`) is sequenced strictly after Phase 1b
("With visual baseline in hand...") and needs no changes — its cross-check
and gap-detection logic works the same regardless of how the baseline was
obtained.

tce has no existing "detect an optional session capability" mechanism. The
closest precedents (see research doc) are the LSP static-conditional
("if a configured LSP server exists, use it") repeated in the three codebase
agents, and — the closer structural match — `init.md:290-293`'s empirical
"try the ticket-read mechanism; if it fails, resolve with the user now"
pattern. Neither is reused verbatim; Phase 1b needs its own version of the
same shape: check for capability, attempt, ask only for what's missing,
confirm with the user, fall back on absence/failure/preference.

`.claude/tce/profile.md` (and its template,
`plugins/tce/templates/tce/profile.md`) has no field for a dev-server URL
today, and design_explore.md never reads `profile.md` at all currently. Per
the question checkpoint, the user chose to add a profile.md field (over
always asking), so the plan must also touch the template, `/tce:init`'s fill
and idempotency logic, and `/tce:refresh`'s scope note, per this repo's
"Migrations & version markers" and "`/tce:refresh` re-analysis" rules in
`CLAUDE.md`.

### Key Discoveries:

- `plugins/tce/commands/design_explore.md:231-240` — the command's only other
  browser-touching mechanism (`open`, to show generated mockups to the user)
  is the opposite direction from what's needed here and requires no changes.
- `plugins/tce/commands/init.md:290-293` — the "try it, resolve on failure"
  pattern is the best structural template for the new Phase 1b logic.
- `plugins/tce/commands/work.md:117-129` and `quickfix.md:168,249` — neither
  composite re-describes Phase 1b/1c internals; both only reference whether
  to run `/tce:design_explore` at all. Per the composite-tracking rule, no
  edits to `work.md`/`quickfix.md` are required by this ticket (verified as a
  manual check in Phase 1 below, since this is exactly the kind of thing that
  rule exists to catch).
- `plugins/tce/commands/init.md:442-459` (Idempotency section) currently
  states "Today the only such change is the marker itself" — this sentence
  must be updated once a second migratable change (the new profile.md
  section) exists.

## Desired End State

`/tce:design_explore` Phase 1b first checks whether the session has browser
automation tooling available; if so, it determines what it still needs from
the user (using a recorded dev-server URL from profile.md if present, else
asking and offering to save it), captures desktop and mobile screenshots of
the relevant pages, and asks the user to confirm they show the right
state before proceeding. If no tooling is available, capture fails, or the
user prefers manual, the existing ask-for-screenshots flow runs unchanged.
The hard requirement — no design work without a confirmed visual baseline —
is unchanged and both its verbatim sentences survive the edit.

**Verification:** read the edited `design_explore.md` and confirm: (a) both
original hard-rule sentences appear byte-for-byte unchanged, (b) the new
branch never names a specific tool/MCP/product, (c) the manual path is
reachable and textually intact, (d) `claude plugin validate ./plugins/tce`
passes.

### Key Discoveries:

- No new agents or scripts are needed — this is a prose-only change to a
  markdown command (this repo's "code" for commands).
- The mobile mockup width already established elsewhere in this same file
  (`design_explore.md:210`, `max-width: 390px`) is a natural, already-precedented
  number to reuse for the mobile capture viewport, avoiding an arbitrary new
  constant.

## What We're NOT Doing

- Not starting/serving the user's app automatically (ticket's Out of Scope) —
  the command may ask the user to start it, never attempts to launch it.
- Not changing Phase 1c, Phase 2, Phase 3, Phase 4, or Phase 5 of
  design_explore.md — only Phase 1b's body changes.
- Not storing captured screenshots as workflow artifacts (ticket's Out of
  Scope nice-to-have) — captures are used in-session to build the baseline
  and are not persisted to `thoughts/shared/mockups/`.
- Not naming or requiring any specific browser automation tool/MCP anywhere
  in the command text (core design rule).
- Not adding a dev-server-URL question to `/tce:init`'s interactive dialogs —
  Phase 1 analysis can't reliably detect a *running* dev server from static
  code, so the field starts unset in the template and is filled lazily by
  `/tce:design_explore` (or by hand), not by `/tce:init`'s Q&A flow.
- Not teaching `/tce:refresh` to reconcile the new field — it's optional,
  hand-authored/lazily-filled, not something re-analysis can verify against
  the repo (there's no way to statically confirm a dev-server URL is still
  correct), so it's documented as out of refresh's scope, the same way
  `design-system.md` already is.
- Not bumping `plugins/tce/.claude-plugin/plugin.json`'s version — per this
  repo's precedent (TP-0020 did not bump it for a comparable feature
  addition), version bumps happen at deliberate release time, not per-ticket.

## Implementation Approach

Two independent-but-related changes, done as two phases: (1) the behavioral
rewrite of Phase 1b in `design_explore.md`, which is the ticket's core ask
and stands on its own; (2) the profile.md plumbing for the dev-server URL
field (template + init + refresh docs), which Phase 1b's new text depends on
(it references "profile.md's Dev environment section"), so it must land
before or together with Phase 1 — implemented as Phase 2 here but committed
together since they're one small, indivisible ticket (this repo has no
per-phase automated test suite to gate on between them; splitting the commit
would leave Phase 1b referencing a section that doesn't exist yet in the
history for one commit).

## Phase 1: Rewrite design_explore.md Phase 1b

### Overview

Replace the unconditional ask-for-screenshots block with a capability-check →
attempt → confirm structure, falling back to the existing manual block.

### Changes Required:

#### 1. Phase 1b body

**File**: `plugins/tce/commands/design_explore.md`
**Changes**: Replace lines 63-73 (the entire `### Phase 1b` section) with:

```markdown
### Phase 1b: Visual Baseline — See the Existing UI

**Before proposing any designs, you MUST see what the existing related pages actually look like rendered.** Code research alone is not sufficient — CSS classes can combine in unexpected ways, and you need a visual reference to match the design language faithfully.

**Try to capture the baseline yourself first, if browser automation tooling is available:**

1. Check whether this session has a browser automation capability — a tool (already loaded, or visible as available to load, e.g. through a tool-discovery mechanism) that can navigate to a URL and capture a screenshot. Don't assume any specific tool/MCP/product is present; check what's actually available right now.
2. If no such capability is available, skip straight to the manual path below.
3. If a capability is available, determine what you still need from the user and ask for only that — typically the app's URL, and if relevant, how to start the dev server or log in. Check `.claude/tce/profile.md`'s `## Dev environment` section first: if it records a dev-server URL, use it without asking. If the user gives you a URL that isn't recorded there, offer to save it for next time.
4. Navigate to each relevant page and capture both a desktop-width and a mobile-width screenshot (desktop ~1280px; mobile ~390px — the same mobile reference width this command already uses for mockup scenes).
5. Show the user what you captured (or describe it, if you can't display images directly) and ask them to confirm it shows the right page and state before proceeding.
6. If the user confirms, that's your visual baseline — proceed to Phase 1c. If they don't confirm, or capture fails at any point (navigation error, tool error, page not reachable), fall back to the manual path below.

**Manual path (fallback — no tooling available, capture failed, or the user prefers it):**

Ask the user to provide screenshots of the relevant existing pages (desktop and mobile):

> I need to see the current [page name] on desktop and mobile to match the design language accurately.
>
> Could you share screenshots of the desktop and mobile views?

**Only proceed once you have a visual reference.** Do not skip this step. Code research supplements visual verification — it does not replace it.
```

Note: both hard-rule sentences (the opening "**Before proposing any
designs...**" and the closing "**Only proceed once you have a visual
reference.** Do not skip this step...") are carried over **byte-for-byte**
from the original — this is a hard constraint, not a suggestion (ticket
acceptance criterion: "preserved verbatim").

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` passes (repo root)
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

- [x] Both original hard-rule sentences appear byte-for-byte unchanged in the new Phase 1b
- [x] No specific tool/MCP/product name appears anywhere in the new Phase 1b text
- [x] The manual (ask-the-user) path is textually intact and reachable (steps 2 and 6 both route to it)
- [x] Phase 1c (`design_explore.md:75-116`, now shifted by the line-count delta) still reads correctly as "immediately after Phase 1b" with no dangling references
- [x] `grep -n "design_explore" plugins/tce/commands/work.md plugins/tce/commands/quickfix.md` shows no text that mirrors Phase 1b/1c internals needing updates (confirms the Key Discoveries note above still holds after the edit)

---

## Phase 2: Add the optional Dev environment field to profile.md

### Overview

Give Phase 1b's new "check profile.md for a recorded dev-server URL" step
somewhere to read from and write to, and keep `/tce:init`/`/tce:refresh` in
sync with the new template shape per this repo's config-migration rules.

### Changes Required:

#### 1. Template: new section

**File**: `plugins/tce/templates/tce/profile.md`
**Changes**: Insert a new section directly after `## Commands` (before
`## Code map`):

```markdown
## Dev environment

Optional. Lets `/tce:design_explore` reach the running app for automated
visual-baseline screenshot capture instead of asking every time. Left unset
until `/tce:design_explore` fills it in (with your approval) the first time
it needs a URL, or you fill it in by hand.

- **Dev server URL:** [not set]
```

#### 2. This project's own profile.md

**File**: `.claude/tce/profile.md`
**Changes**: None. This repo has no application runtime ("No application
runtime or package manager" per its `## Tech stack`), so a dev-server URL
field is not meaningful here; it will surface only if `/tce:init` or
`/tce:refresh` is re-run in this repo per the Idempotency mechanism (Phase 2
item 3 below), consistent with how other template-shape changes propagate to
existing projects.

#### 3. init.md: fill instructions + idempotency note

**File**: `plugins/tce/commands/init.md`

**Change A** — Phase 4, item 1 (`init.md:321-327`), the section-fill list.
Currently:

```markdown
1. **`.claude/tce/profile.md`** — fill in every section from your analysis: Tech stack,
   Commands, Code map, Conventions, Commit convention, and Preferred research sources.
   Replace the `[...]` / `<...>` / `https://...` placeholders with real values, and
   delete guidance lines and table rows that don't apply. (Read the copied file first
   to see the exact structure to populate.) Fill the `tce-config-version` HTML comment
   on the first line with the installed plugin version (the `version` field of
   `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`).
```

Add one sentence after the existing paragraph: "Leave `## Dev environment`
as the template's `[not set]` placeholder — it isn't derivable from static
analysis; `/tce:design_explore` (or the user, by hand) fills it in later."

**Change B** — Idempotency section (`init.md:442-459`). Currently ends:

```markdown
- **Older or missing** — tell the user the config was written by an older tce
  (a `profile.md` without the comment predates version markers), walk through
  any config changes the newer version requires, and update the marker to the
  installed version. Ask before writing, as always. Today the only such change
  is the marker itself: a `profile.md` without the comment needs the comment
  line added.
```

Replace the last sentence ("Today the only such change is the marker itself:
a `profile.md` without the comment needs the comment line added.") with:

```markdown
Today these are the changes to walk through:

- A `profile.md` without the comment needs the version-marker comment line added.
- A `profile.md` without a `## Dev environment` section (added for
  `/tce:design_explore`'s automated baseline capture) needs the section
  inserted, directly after `## Commands`, with its `[not set]` placeholder —
  never guess a URL.
```

#### 4. refresh.md: scope note

**File**: `plugins/tce/commands/refresh.md`
**Changes**: In the "Project context" section (`refresh.md:27-32`), the
sentence "`design-system.md` is not yet covered." becomes: "`design-system.md`
and the optional `## Dev environment` section are not covered — the latter is
hand-filled (by `/tce:design_explore` or the user), not something re-analysis
can verify against the repo."

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` passes (repo root)
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

- [x] `plugins/tce/templates/tce/profile.md` has the new section in the right place and it matches the structure Phase 1b's new text refers to ("profile.md's Dev environment section")
- [x] `init.md`'s Phase 4 fill instructions and Idempotency section both mention the new section (no drift between what Phase 4 says to write for fresh installs and what Idempotency says to backfill for existing ones)
- [x] `refresh.md`'s scope note reads correctly alongside the existing `design-system.md` callout
- [x] This repo's own `.claude/tce/profile.md` is intentionally left unchanged (confirmed not an oversight — see rationale above)

---

## Testing Strategy

### Manual Testing Steps:

1. Read the full edited `design_explore.md` end to end and confirm Phase 1b
   reads coherently with Phase 1c immediately following it.
2. Read the full edited `init.md` and `refresh.md` sections in context (not
   just the diff) to confirm no leftover references to the old single-sentence
   Idempotency wording.
3. Diff-review that no other phase of `design_explore.md` (2 through 5) was
   touched.

## Migration Notes

Existing projects with a `.claude/tce/profile.md` written before this change
won't have `## Dev environment` until they next run `/tce:init` (which will
offer to backfill it per the updated Idempotency section) or `/tce:refresh`
(which explicitly does not manage this field, per its scope note) — or until
`/tce:design_explore` is invoked and finds the section missing, in which case
it should treat "no `## Dev environment` section" the same as "section
present but unset" (always ask; the optional-save offer only applies to
whichever profile.md shape a given project actually has, and the command must
not fail on an older profile.md missing the section entirely).

## References

- Original ticket: `thoughts/shared/tickets/TP-0021-design-explore-auto-baseline.md`
- Research: `thoughts/shared/research/2026-07-06-TP-0021-design-explore-auto-baseline.md`
- Phase 1b target: `plugins/tce/commands/design_explore.md:63-73`
- Closest existing capability-check precedent: `plugins/tce/commands/init.md:290-293`
- Profile template: `plugins/tce/templates/tce/profile.md`
- Idempotency mechanism being extended: `plugins/tce/commands/init.md:442-459`
