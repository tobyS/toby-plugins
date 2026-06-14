---
date: 2026-06-14
ticket: TP-0004
topic: "Detect and refresh a stale project profile (/tce:refresh)"
status: complete
last_commit: f9dc560
---

# Research: Profile-drift detection and `/tce:refresh` (TP-0004)

## Summary

TP-0004 asks for two coordinated additions to the **tce** plugin:

1. A new **`/tce:refresh`** command that re-analyzes the consuming project, compares
   the findings against `.claude/tce/profile.md`, presents the proposed changes as a
   reviewable diff, and writes only after the user approves — preserving hand-authored
   sections (Conventions, Preferred research sources).
2. A **non-blocking drift advisory** folded into `/tce:research_codebase` (and mirrored
   into the composite `work.md` / `quickfix.md`) that, having already explored the
   codebase, notices when reality contradicts the profile and recommends running
   `/tce:refresh`. It never edits the profile itself.

The good news: **almost all the machinery already exists** inside `init.md`. Init
already does the repo analysis, owns the version-marker convention, and already has an
"Idempotency" section whose behavior ("read the existing file, show what differs from a
fresh analysis, ask before writing, don't clobber") is *exactly* the propose-a-diff
posture TP-0004 wants. The work is therefore primarily **prompt-engineering across
markdown command files** — extract/share the analysis+diff logic, add one new command
file, and inject a read-only advisory step into the research flow plus its two mirrors.
There is **no new infrastructure** (no scripts, no new file formats). The dominant risk
is the repo's several "keep-in-sync" contracts (composite commands, the duplicated
dialog block, the version-marker upgrade list).

## Key findings

### 1. Init already contains the entire analysis routine `/tce:refresh` needs

`plugins/tce/commands/init.md` Phase 1 (`init.md:71-136`) does all repo analysis itself
with Glob/Grep/Read/Bash (spawning research subagents only for large/unclear layouts):

- **Stack & tooling** (`init.md:79-82`) — inspects `package.json`, `composer.json`,
  `go.mod`, `pyproject.toml`/`requirements.txt`, `Cargo.toml`, `Gemfile`, `pom.xml`,
  `build.gradle`; identifies languages, frameworks, package manager.
- **Commands** (`init.md:83-86`) — derives test/typecheck/lint from `package.json`
  scripts, `composer.json` scripts, `Makefile`, `Taskfile`, `.github/workflows/*`, with
  the directory each runs in.
- **Layout / code map** (`init.md:87-91`) — monorepo detection + the code-map table.
- **Conventions** (`init.md:92-94`) and **Preferred research sources**
  (`init.md:95-101`) — skim CLAUDE.md/README + dependency lists.

This is the same analysis a refresh needs. The implication for the "new command vs.
extend init" question (below): the analysis logic should be **described once and shared**,
not duplicated, or the two will drift.

### 2. Init writes and stamps the profile via copy-then-fill

Phase 4 (`init.md:278-296`) copies the skeleton and fills it:

```
cp "${CLAUDE_PLUGIN_ROOT}/templates/tce/profile.md" "${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md"
```

then fills every section and **stamps the version marker** on line 1 from
`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` `version` (currently `2.0.0` —
`plugins/tce/.claude-plugin/plugin.json:3`). The template
(`plugins/tce/templates/tce/profile.md`) is the declared **single source of truth** for
section structure: line 1 `<!-- tce-config-version: FILLED-BY-INIT -->`, then
`# Project Profile`, `## Tech stack`, `## Commands`, `## Code map`, `## Conventions`,
`## Preferred research sources`.

`/tce:refresh` differs from init here: it must **edit in place** (preserving manual
content), not `cp` the skeleton (which would clobber). It diffs section-by-section
against the existing file.

### 3. The version-marker / idempotency logic is the model for the diff UX

`init.md:400-416` (the "Idempotency" section) is the closest existing precedent and is
effectively a spec for `/tce:refresh`'s behavior:

- `init.md:402-405`: "If `.claude/tce/profile.md` ... already exist, do not clobber
  them. Read them, show what differs from your fresh analysis, and ask whether to update
  specific values. Treat re-running `/tce:init` as 'review and amend ...', not 'start
  over.'"
- `init.md:407-416`: compare the `tce-config-version` comment vs installed version —
  Same → "already up to date (v[X.Y.Z])"; Older/missing → walk through required changes,
  update the marker, "Ask before writing, as always."

**All version-marker handling is Claude-driven prose — there is no shell helper.**
`tce-config-version` appears in exactly three places: `init.md:294`, `init.md:407`,
`templates/tce/profile.md:1` — never in a script. `lib.sh` only offers
`tce_project_root()` (`lib.sh:11-13`). So `/tce:refresh` keeps the marker correct the
same way init does: in prose, reading the version from `plugin.json`.

TP-0003 (ticket `thoughts/shared/tickets/TP-0003-init-upgrade-migration.md`, plan
`thoughts/shared/plans/2026-06-12-TP-0003-init-upgrade-migration.md`) established this
machinery; TP-0004 builds directly on it. The CLAUDE.md "Migrations & version markers"
contract says: **if a new plugin version changes what the config must contain, extend
the init's Idempotency upgrade list in the same commit** — relevant only if refresh
introduces structural changes (it should not).

### 4. Best insertion points in the research flow

`research_codebase.md` is a linear numbered-step prompt. It reads the profile exactly
once, as guidance, in the preamble (`research_codebase.md:14`) — it never compares the
profile against observed reality (no drift concept exists today). Structure:

- Step 3 (`:145`) spawns subagents; **Step 4 (`:201-211`) waits + synthesizes** — first
  point where stack/structure findings are fully in main context.
- Step 6 (`:230-309`) writes the research document (template includes `## Open
  Questions` at `:307`).
- Step 8 (`:319-328`) presents a summary + "Next command" line.
- Step 9 (`:330`) commits via `/tce:commit`.

**Two coordinated seams** (per the analyzer):
- **Detect** after Step 4 synthesis, before the Step 5/6 write (a new step or a Step 4
  sub-bullet) — the codebase is explored but the document isn't written yet.
- **Surface** non-blockingly: a small section in the Step 6 document template (natural
  slot near `## Open Questions`, `:307`) **and** an echo in the Step 8 presentation so
  the user sees "profile looks stale — consider `/tce:refresh`" alongside the next-command
  line.

**Caveat — documentarian carve-out:** `research_codebase.md:58-66` is a strict "ONLY
describe what exists; do NOT recommend" block. A `/tce:refresh` recommendation is the one
place research steps outside pure documentation, so the new wording needs an explicit
carve-out to coexist with that block. The detection itself (comparing observed reality to
the profile) is read-only and consistent with the documentarian stance.

### 5. Composite-command mirroring obligations (hard requirement)

Per CLAUDE.md ("Composite commands must track the single-step commands") and the in-file
lock-step clauses (`work.md:22`, `quickfix.md:22`), the drift step added to research
**must** be mirrored, in the same commit, into:

- **work.md Phase 1** — the inline research-step list at `work.md:77-90` enumerates
  Decompose → Spawn → Wait → Synthesize → Write → permalinks → quality. Insert the
  detection step between "Synthesize findings" and "Write the research document"
  (`:84-86`). But Phase 1 is autonomous and explicitly suppresses presentation
  (`work.md:96` "Do NOT present the research ... Do NOT ask for follow-up questions"), so
  the advisory cannot be printed mid-Phase-1 the way research Step 8 does. The mirror must
  route the advisory to **the written document and/or the Phase 2 question checkpoint**
  (`work.md:100-169`) — see Open Questions.
- **quickfix.md Phase 3** — inline list at `quickfix.md:179-187`; insert detection
  between Spawn (`:185`) and Write (`:187`). quickfix is fully autonomous/non-interactive
  (`:185`), so the advisory goes into the written document and/or the **Phase 6 final
  summary** template (`quickfix.md:243-267`).

Profile path string `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` currently appears once
per file: `research_codebase.md:14`, `work.md:17`, `quickfix.md:17`.

### 6. Command-file conventions for the new `/tce:refresh` file

- **Frontmatter** is minimal: `description` always; `argument-hint` only if it takes an
  argument (`discuss.md:1-4` with hint, `commit.md:1-3` without). No `name` field —
  derived from filename. `/tce:refresh` takes no argument → no `argument-hint`.
- **Skeleton** (per `commit.md`): frontmatter → `# Title` (Title Case) → one-sentence
  task → `## Project context` (ships in tce, stack-agnostic, read
  `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`, "if missing run `/tce:init`") → body →
  closing `## Important`.
- **Script refs** use `"${CLAUDE_PLUGIN_ROOT}/scripts/..."`; profile path uses
  `${CLAUDE_PROJECT_DIR}/...`; template at `${CLAUDE_PLUGIN_ROOT}/templates/tce/profile.md`.
- **Dialog block:** if `/tce:refresh` uses AskUserQuestion, it must include the
  byte-identical "AskUserQuestion dialog guidelines" block. Today it is duplicated in
  **six** files (`init`, `research_codebase`, `create_plan`, `work`, `quickfix`,
  `tmt/init` — see `CLAUDE.md` "The AskUserQuestion guidelines block is duplicated").
  Adding a seventh copy expands that sync contract.

### 7. Approval / diff patterns to model

There is **no literal unified-diff convention** in the repo. The existing
"propose-then-write-on-approval" patterns are:
- Init's Analyze→Propose→Refine→Write phases (`init.md:12-13`, `:138-140`, `:278`).
- Per-edit free-form approval ("apply only the edits the user approves") —
  `init.md:374-378` (CLAUDE.md section edits), and `design_explore.md:106-115` (gated
  edit to `.claude/tce/design-system.md`).
- "Show what differs from a fresh analysis, then ask" — the Idempotency block
  (`init.md:400-416`).

`/tce:refresh` should present its proposal as a clear before/after per changed section
(prose/fenced block, since no diff helper exists) and gate the write on approval, likely
per-section so manual sections can be left untouched.

## Code references

- `plugins/tce/commands/init.md:71-136` — Phase 1 repo analysis (the shared routine)
- `plugins/tce/commands/init.md:278-296` — Phase 4 write + version stamp
- `plugins/tce/commands/init.md:400-416` — Idempotency / version-marker diff posture
- `plugins/tce/templates/tce/profile.md:1-53` — profile structure + marker placeholder
- `plugins/tce/.claude-plugin/plugin.json:3` — version source (`2.0.0`)
- `plugins/tce/scripts/lib.sh:11-13` — `tce_project_root()`
- `plugins/tce/scripts/check-init.sh` — project-state-aware nudge precedent
- `plugins/tce/commands/research_codebase.md:14,58-66,201-211,307,319-328` — profile
  read, documentarian block, synthesis, doc template, presentation
- `plugins/tce/commands/work.md:22,77-90,96,100-169` — lock-step clause + Phase 1 mirror
- `plugins/tce/commands/quickfix.md:22,179-187,243-267` — lock-step + Phase 3 mirror
- `plugins/tce/commands/commit.md:1-19` / `discuss.md:1-4` — command skeleton/frontmatter
- `CLAUDE.md` — core design rule, composite-sync rule, dialog-block-sync rule,
  "Migrations & version markers"

## Historical context

- TP-0003 (`thoughts/shared/tickets/TP-0003-init-upgrade-migration.md`, plan
  `thoughts/shared/plans/2026-06-12-TP-0003-init-upgrade-migration.md`) introduced the
  version markers (`tce-config-version`, `TMT_CONFIG_VERSION`), the idempotency/upgrade
  walk-through, and claude-template migration. TP-0004 reuses all of it.
- TP-0001 (`thoughts/shared/tickets/TP-0001-askuserquestion-copy.md`) established the
  duplicated-dialog-block contract a new command with a dialog must honor.

## Open questions

These need human judgment before planning (carried to the Phase 2 checkpoint):

1. **New standalone command vs. extending `/tce:init`.** The analysis + diff logic is
   init's. Options: (a) ship `/tce:refresh` as a thin standalone command that *describes*
   re-analysis and diffing in its own words (some duplication of init's Phase 1 prose);
   (b) make `/tce:refresh` explicitly reference/reuse init's Phase 1 + Idempotency
   sections so the description lives in one place. Recommendation leans (a) for a clean
   user-facing surface, with a CLAUDE.md sync note tying refresh's analysis description
   to init's — but this is the central design call.

2. **How refresh presents the diff and gates writing.** Per-section before/after with
   per-section approval (preserves manual sections cleanly) vs. one batched
   approve/decline. Recommendation: per-section, so factual sections (Tech stack,
   Commands, Code map) refresh while Conventions / Preferred research sources are left
   alone unless the user opts in.

3. **Where the drift advisory surfaces in the autonomous composites.** In `work.md` and
   `quickfix.md` the research phase must not interrupt. For `work.md`: put the advisory in
   the research document only, or also surface it at the Phase 2 question checkpoint? For
   `quickfix.md` (fully autonomous): research document only, or also the Phase 6 summary?
   Recommendation: written-document always; additionally echo in work's Phase 2 intro and
   quickfix's Phase 6 summary so a human actually sees it.

4. **Drift sensitivity / signal set.** What counts as "drift" worth advising on — to keep
   the nudge trustworthy (low false-positive)? Recommendation: advise only on concrete,
   high-confidence mismatches (a manifest/lockfile shows a stack the profile doesn't
   mention; a test/lint command in the profile no longer exists; a code-map directory is
   gone/moved). Soft wording, never blocking.

## Related research

- `thoughts/shared/research/2026-06-12-TP-0003-init-upgrade-migration.md`
