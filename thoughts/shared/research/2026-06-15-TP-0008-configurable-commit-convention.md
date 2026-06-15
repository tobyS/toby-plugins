---
date: 2026-06-15
ticket: TP-0008
topic: Make commit convention configurable via /tce:init
git_commit: 1f93aee5d395573d1c0376f738fa76dea64f8285
researcher: Claude (Opus 4.8)
status: complete
---

# Research: Configurable commit convention via /tce:init (TP-0008)

## Research question

How should tce stop hardcoding Conventional Commits and instead let `/tce:init`
agree a commit convention (from a small standard set), persist it to
`.claude/tce/profile.md`, and have every commit-writing command read and follow it?
Where exactly does the convention live today, what are all the touch points, and how
do the three cross-cutting repo rules (verbatim dialog copy, version-marker upgrade
list, refresh-tracks-init) apply?

## Summary

- The commit-message format is **defined in exactly one place**:
  `plugins/tce/commands/commit.md:59-75` ("Use conventional commits", the
  `<keyword>(<ticket-id>): <description>` shape, the keyword list, the 72-char rule).
- **Every other command defers to `/tce:commit`** for the format — *except* four
  files that **inline literal `<keyword>(<id>): ...` strings** baking in the
  Conventional shape: `quickfix.md` (lines 119, 147, 169, 212-215), `ticket.md`
  (line 179), `implement.md` (line 117, an example in the status-file template).
  Those literals must be neutralized/parameterized; everything else inherits a
  configurable format automatically.
- The commit convention has **no dedicated home** in `profile.md` today — it is only
  named as an *example* inside the free-form `## Conventions` prose
  (`templates/tce/profile.md:41`). The fix should add a **dedicated, named section**
  so `commit.md` can read it deterministically (matches the ticket's AC).
- `/tce:init` writes profile.md by **copying the template skeleton and filling it**
  (init.md:282-298). Adding the setting touches: a new Phase 1 detection step (git
  history sniff — *new* behavior), a new **verbatim** Phase 2 dialog (contract-
  governed + the 9-copy guidelines rule), a new fill step in Phase 4, a new bullet in
  the Idempotency upgrade list, a version bump (3.1.0 → 3.2.0) in both manifests, and
  the template file itself.
- **Refresh question resolved (recommendation):** treat the convention as a
  *hand-authored / agreed* setting (like the `tickets.md` policy choices and the
  `## Conventions` block), **not** a factual re-derived value. `/tce:refresh` already
  leaves hand-authored sections untouched (refresh.md:78-79, 90-93), so it needs **no
  re-derivation logic** — only (optionally) a one-line mention in its preserved list
  for hygiene. The CLAUDE.md "refresh tracks init" rule is scoped to *factual*
  sections (Tech stack / Commands / Code map / backend adapter); a dialog-seeding git
  sniff is not one of those.

## Detailed findings

### 1. Current commit-format definition and all commit sites

Canonical definition — `plugins/tce/commands/commit.md`:

- `commit.md:2` (frontmatter): "...and a conventional-commit message."
- `commit.md:25-27`: docs-only vs code-commit split (docs-only skips
  tests/typecheck/lint). Independent of the message format but worth preserving.
- `commit.md:59-75`: the **`## Commit Message Format`** section — the block to
  parameterize:
  - "Use conventional commits." + `<keyword>(<ticket-id>): <description>` + optional
    body.
  - **Keywords:** feat, fix, refactor, docs, test, chore, style, perf, ci, build.
  - Rules: what-not-how, why for non-obvious, first line < 72 chars.
- `commit.md:15-19`: already reads `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` for
  test/typecheck/lint commands — **the exact pattern to extend** with a
  commit-convention read.

Sites that **inline literal commit strings** (must change):

| File | Lines | Literal |
|------|-------|---------|
| `quickfix.md` | 119, 147, 169 | `docs([PREFIX]-XXXX): create quickfix ticket…` / `…research codebase…` / `…create implementation plan…` |
| `quickfix.md` | 211-215 | summary block: `docs(...)` ×3 + `feat/fix([PREFIX]-XXXX): …` |
| `ticket.md` | 179 | `docs([PREFIX]-XXXX): create ticket for <brief description>` |
| `implement.md` | 117 | status-file example `feat([PREFIX]-XXXX): commit message` |

Sites that **only defer** to `/tce:commit` (inherit the configurable format, no
change needed): `research.md:362,372`, `plan.md:598`, `work.md:95,203,234,260`,
`review.md:407`, `refresh.md:145`. `init.md` only mentions the *word* commit
(version-marker / migration / commit-scope references), no format text.

**Implication:** the docs-only commits in quickfix/ticket are always `docs(...)`
today. Under a non-Conventional convention they must follow the chosen format too
(e.g. plain `TP-0008: create ticket for …`, or `#8: …`). The cleanest fix is to
replace the inlined literals with instructions to "format the message per the
project's commit convention (see `.claude/tce/profile.md`); this is a docs-only
change" rather than a hardcoded `docs(...)` string.

### 2. profile.md template and where the setting lives

`plugins/tce/templates/tce/profile.md` (54 lines). Section order: line 1 version
marker `<!-- tce-config-version: FILLED-BY-INIT -->`, then `# Project Profile`
→ `## Tech stack` → `## Commands` → `## Code map (where things live)` →
`## Conventions` → `## Preferred research sources`.

- `## Conventions` (lines 39-42) placeholder already names "commit discipline" as an
  example do/don't. So a free-form convention has a *pre-existing prose home* — but
  it is unstructured and not reliably machine-readable.
- **Recommendation:** add a **dedicated `## Commit convention` section** (a
  structured sibling) that records (a) the chosen convention name and (b) its
  concrete message-format spec including ticket-ID placement. `commit.md` reads this
  section verbatim. This satisfies the ticket AC ("named section … records both the
  convention and its concrete message-format spec") and gives deterministic runtime
  parsing.

### 3. /tce:init mechanics (init.md, 449 lines)

Phase map: Phase 0 preflight (57-69); **Phase 1 analyze (71-138)**; **Phase 2
propose + dialogs (140-253)**; Phase 3 refine (255-278); **Phase 4 write (280-406)**;
**Idempotency (408-438)**; Notes (440-449).

- **Phase 1 detection** (71-138): 8 gather items. Git history is read **only** for
  ticket-system detection (GitHub `#NNN`/`Fixes #NNN` at 108-110; Jira `KEY-123` at
  111-112). The **Conventions** item (92-94) skims `CLAUDE.md`/`README.md`, *not* git
  log. So a "sniff commit convention from `git log`" step is **new** behavior — and
  it is naturally *dialog-seeding* (pre-select the default), mirroring how init
  already sniffs commits to pre-select the ticket system.
- **Phase 2 dialogs** (184-253): three verbatim dialog sites (ticket system; status
  policy; creation policy). CLAUDE.md: this dialog copy "is part of the commands'
  contract … never improvised at runtime (TP-0001)". A new commit-convention dialog
  added here becomes contract-governed too.
- **Phase 4 fill** (282-298): copies `templates/tce/{profile,tickets}.md` then fills
  sections (Tech stack, Commands, Code map, Conventions, Preferred research sources)
  and stamps the version marker from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.
  A new section needs a new fill step here.
- **Idempotency upgrade list** (415-427): compares the profile's `tce-config-version`
  marker to the installed version; "older or missing" walks the per-version config
  changes and re-stamps. Current bullets cover the marker-add and **v3.1.0** (tickets.md
  layout + reject moment). **A new `**v3.2.0**` bullet is required** ("profile.md
  gained a `## Commit convention` section; if missing, walk the user through choosing
  one and add it"). CLAUDE.md mandates extending this list in the same commit.

### 4. The AskUserQuestion guidelines block + verbatim copy contract

The `### AskUserQuestion dialog guidelines` block is duplicated **byte-identically
across 9 files**: `tce/commands/{init,plan,research,work,quickfix,ticket,refresh}.md`
and `tmt/commands/{init,update}.md`. We are **not** changing that block (no edit →
no 9-copy sync needed). But the **new dialog copy** we add to `init.md` Phase 2 is
itself part of the contract; word it carefully (it ships frozen).

### 5. /tce:refresh and the "refresh tracks init" rule (the open question)

`refresh.md` Phase 1 (53-79) "investigate … the same way `/tce:init` does," but only
for **factual** sections: Tech stack, Commands, Code map, ticket-system backend
adapter. Crucially refresh.md:78-79: "Do **not** re-derive **Conventions** or
**Preferred research sources** … those are hand-authored." Phase 2 (86-93) splits
**factual (refreshed)** vs **hand-authored (preserved)**; policy choices live in the
preserved set.

CLAUDE.md rule, verbatim scope: *"When you change what `/tce:init` Phase 1 detects,
or how it fills profile.md's **factual sections (Tech stack, Commands, Code map)** or
the `tickets.md` backend adapter, update `/tce:refresh`'s Phase 1 in the same
commit."*

**Resolution:** classify the commit convention as **hand-authored/agreed**, not
factual. Then:
- refresh does **not** re-derive it; it leaves the `## Commit convention` section
  untouched (its default behavior for non-factual sections), which is the desired
  outcome and matches the ticket's "refresh out of scope".
- The git-history sniff in init is **dialog-seeding only** (pre-select the default),
  exactly like the existing ticket-system commit sniff — not a factual re-derivation,
  so the rule's *factual-section* trigger is not tripped.
- **Recommended hygiene edit (small, arguably required for honesty):** add the new
  section name to refresh's preserved list (refresh.md:90-93) so it is explicitly
  protected, and add a one-line note that the convention is agreed at init and not
  reconciled by refresh. This keeps the two commands provably in sync without giving
  refresh any new detection logic.

This is the main design decision for the checkpoint (see Open Questions).

### 6. Ticket-ID placement per backend (the `#<ticket-number>` convention)

tce is backend-agnostic: the canonical ticket ID form comes from
`.claude/tce/tickets.md` (for tmt: `TP-0008`; for GitHub: `#123`; etc.). The
`#<ticket-number>` convention is most natural for issue trackers. The robust,
backend-agnostic model: the stored format spec references **"the canonical ticket ID
per tickets.md"** with a per-convention placement, and does **not** try to extract a
bare integer:
- Conventional → `type(<canonical-id>): desc` (e.g. `feat(TP-0008): …`, `feat(#123): …`).
- Plain → `<canonical-id>: desc` (e.g. `TP-0008: …`).
- `#<ticket-number>` → `#<canonical-id-number>: desc` — natural as `#123:` on GitHub;
  on tmt the canonical ID is `TP-0008` (no bare number), so this convention is simply
  a poor fit for tmt and users on tmt would pick Conventional or Plain. Recommend
  documenting it as "intended for numeric issue trackers" rather than inventing a
  number-extraction rule that breaks tce's backend-agnosticism.

### 7. git-history detection heuristic (init Phase 1)

Low-risk, best-effort. Over the last ~20-50 subjects from `git log --format=%s`:
- majority match `^\w+(\(.+\))?: ` (and a known keyword) → **Conventional**;
- majority match `^#?\d+[: ]` → **`#<ticket-number>`**;
- otherwise → **Plain / freeform**.
Empty or mixed history → default to **Conventional Commits**. This only seeds the
dialog default; the user always confirms, so a wrong guess is harmless.

## Code references

- `plugins/tce/commands/commit.md:59-75` — canonical commit-format block (to parameterize)
- `plugins/tce/commands/commit.md:15-19` — existing profile-read pattern to extend
- `plugins/tce/commands/quickfix.md:119,147,169,211-215` — inlined `docs(...)` literals
- `plugins/tce/commands/ticket.md:179` — inlined `docs(...)` literal
- `plugins/tce/commands/implement.md:117` — status-file `feat(...)` example
- `plugins/tce/templates/tce/profile.md:39-42` — `## Conventions` (current home / template seed)
- `plugins/tce/commands/init.md:71-138` — Phase 1 analysis (add detection step)
- `plugins/tce/commands/init.md:184-253` — Phase 2 verbatim dialogs (add convention dialog)
- `plugins/tce/commands/init.md:282-298` — Phase 4 fill + version stamp
- `plugins/tce/commands/init.md:415-427` — Idempotency upgrade list (add v3.2.0 bullet)
- `plugins/tce/commands/refresh.md:53-79,86-93` — factual-vs-hand-authored split (preserved list)
- `plugins/tce/README.md:90-94,98,142,177-180` — docs to update
- `plugins/tce/.claude-plugin/plugin.json:3` — version `3.1.0` (bump to 3.2.0)
- `.claude-plugin/marketplace.json` — tce entry version (bump to match)

## Related prior work (thoughts/)

- TP-0003 (`research/2026-06-12-TP-0003-init-upgrade-migration.md`, plan) — the init
  idempotency upgrade list + version-marker mechanism this ticket extends.
- TP-0004 (`research/2026-06-14-TP-0004-profile-drift-refresh.md`, plan) — `/tce:refresh`
  analysis vs init Phase 1, factual-vs-hand-authored split (directly informs the
  refresh decision).
- TP-0001 (`research/2026-06-12-TP-0001-askuserquestion-copy.md`, plan) — the dialog
  copy contract + duplicated guidelines block.

## Open questions for planning (to resolve at the checkpoint)

1. **profile.md storage shape** — dedicated `## Commit convention` section
   (recommended, deterministic read, matches AC) vs folding into `## Conventions`.
2. **Refresh handling** — preserved-only with a one-line hygiene note in refresh's
   preserved list (recommended) vs no refresh change at all vs full refresh
   reconciliation (ticket says out of scope).
3. **`#<ticket-number>` ID resolution** — reference the canonical ID per tickets.md
   with per-convention placement and document `#<n>` as "for numeric issue trackers"
   (recommended) vs invent a bare-number extraction rule (breaks backend-agnosticism).
4. (Derivable, will set in plan unless overridden) git-history heuristic per §7;
   exact per-convention spec text per §6; version bump 3.1.0 → 3.2.0.

## tce config drift

None. The project's `.claude/tce/profile.md` version marker (3.1.0) matches the
installed plugin, and the profile/tickets adapter still match the repo. No
`/tce:refresh` recommended.
