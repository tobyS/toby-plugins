# User-First README Rework + CONTRIBUTING.md Extraction Implementation Plan

## Overview

Rewrite the three READMEs (`README.md`, `plugins/tce/README.md`,
`plugins/tmt/README.md`) into user-first, best-practice documentation, and extract
all "how to develop the plugin itself" content into a new root `CONTRIBUTING.md`
linked from the bottom of each README. Documentation-only change — no plugin
behavior, scripts, hooks, manifests, or versions are touched.

## Current State Analysis

(From research `thoughts/shared/research/2026-06-17-TP-0011-readme-rework-user-first.md`.)

- **No `CONTRIBUTING.md` or `LICENSE` file** exists anywhere in the repo.
- **Marketplace `README.md` (95 lines)** mixes user docs with development content:
  user-facing intro + `## Plugins` + `## Add the marketplace` + `## Update`
  (`README.md:1-33`), then a `## Development` section (`README.md:35-91`: the
  "two names" note, repo layout tree, update gating, validate & release), then a
  2-line `## License` (`README.md:93-95`, "provided as-is", no LICENSE file).
- **tce `README.md` (185 lines)** is essentially all usage content but leads with
  mechanics. Heading carries a rent-the-toby.com link
  (`plugins/tce/README.md:1`). Command table uses a workflow "Step" column
  (`plugins/tce/README.md:133-146`). Conceptual sections ("Why context
  engineering?", "How project parameterization works") are user-relevant and stay.
- **tmt `README.md` (126 lines)** is pure usage; heading already
  `# tmt — Toby Markdown Tickets` (`plugins/tmt/README.md:1`). No dev content.
- **`CLAUDE.md`** holds the authoritative dev rules (layout, project-agnostic
  design rule, composite-command tracking, Testing changes, Releasing,
  Conventions) — `CONTRIBUTING.md` references it, does not duplicate it.
- **`TODO.md`** is a maintainer backlog (dev-side), not linked from any README.
- **Test command** (`.claude/tce/profile.md`): `claude plugin validate .` plus
  `claude plugin validate ./plugins/tce` and `./plugins/tmt`. No typecheck/lint.
  READMEs and `CONTRIBUTING.md` are not themselves validated by these, but the
  commands confirm no manifest/structure broke during the edits.

### Key Discoveries:

- The only real "relocate" is `README.md:35-91` → `CONTRIBUTING.md`; the plugin
  READMEs need restructuring, not content removal.
- The 12 tce commands map losslessly onto four roles: Core (`ticket`, `research`,
  `plan`, `implement`), Shortcuts (`work`, `quickfix`), Helpers (`discuss`,
  `review`, `commit`, `design_explore`), Maintenance (`init`, `refresh`).
- Best practice (research "External Best Practices"): value-first opening (name →
  one-line category+capability tagline → promo callout → install → usage →
  contributing link → license last); grouped command tables suit role-clustered
  commands; sponsor/maintainer callout goes high but outside the H1
  (sindresorhus/got model); CONTRIBUTING.md "don't duplicate, link".

## Desired End State

- A root `CONTRIBUTING.md` exists, holding the relocated development content plus
  contributor basics, and pointing to `CLAUDE.md` for deep design rules.
- All three READMEs open value-first, contain **usage information only**, carry the
  agreed rent-the-toby.com callout after their value section (not in the heading),
  and link to `CONTRIBUTING.md` from the very bottom.
- tce README heading is exactly `# tce — Toby Context Engineering`; its commands are
  presented as four role-grouped tables; it has a table of contents.
- tmt README keeps its heading; gains the callout, value-first ordering, and bottom
  Contributing link.
- `claude plugin validate` passes for the marketplace and both plugins; all
  cross-links resolve; no factual usage detail is lost.

### Decisions locked for this plan

- tce commands: **four grouped tables**, one per role, each with a one-line intro;
  the workflow "Step" column is dropped.
- `CONTRIBUTING.md`: **relocate the Development section + contributor basics, point
  to `CLAUDE.md`** (no duplication of CLAUDE.md's deep rules).
- rent-the-toby.com callout: placed **after the value section**, above install.
- Table of contents: **tce README only**.
- `TODO.md`: **not** linked from CONTRIBUTING.md. **No badges** added (no CI, no
  LICENSE file, no package registry).

### Agreed rent-the-toby.com callout (identical in all three READMEs)

```markdown
> **Built by Toby.** These plugins come out of my daily practice helping
> engineering teams turn experimental AI use into structured, sustainable
> workflows. Need a sparring partner for the hard technical and AI-adoption calls?
> Find me at [rent-the-toby.com](https://rent-the-toby.com).
```

## What We're NOT Doing

- No changes to commands, agents, scripts, hooks, manifests, or templates.
- No version bumps or release tags (no plugin code changes).
- Not creating a `LICENSE` file (the marketplace README's "provided as-is" License
  section stays as prose).
- Not replacing or trimming `CLAUDE.md`; CONTRIBUTING.md references it.
- No per-plugin CONTRIBUTING.md (one root file, per ticket decision).
- No badges, no demo GIF/screenshot, no TOC on the marketplace or tmt READMEs.
- Not linking `TODO.md` from any doc.
- Not changing the marketplace `## Plugins` catalog facts or any usage facts —
  only structure, ordering, headings, and the callout/links.

## Implementation Approach

Four phases, one per file, in dependency order: create `CONTRIBUTING.md` first so
the marketplace README can hand off its Development section, then rework each README.
Each phase is committed separately by `/tce:implement` after its verification. Edits
are surgical where content is preserved (tmt, the tce usage sections) and
structural where content moves (marketplace Development → CONTRIBUTING).

Content-preservation rule for all phases: every usage fact present today (commands
and their one-line purposes, requirements tables, install/update/setup steps,
migration notes, ticket format, agent list) must survive the rewrite — restructure
and re-word for value-first flow, but do not drop information.

---

## Phase 1: Create root `CONTRIBUTING.md`

### Overview

Create a new human-facing `CONTRIBUTING.md` at the repo root that absorbs the
marketplace README's Development content and adds contributor basics, pointing to
`CLAUDE.md` for the deep design rules.

### Changes Required:

#### 1. New file `CONTRIBUTING.md` (repo root)

**File**: `CONTRIBUTING.md`
**Changes**: New file. Human-toned (not agent instructions). Suggested sections:

- **Intro / welcome** — one or two lines: contributions welcome; this repo is the
  `toby-plugins` marketplace with the `tce` and `tmt` plugins under `plugins/`.
- **The two names** — relocate the "Two names, kept distinct" note
  (`README.md:40-47`): `toby-plugins` is the marketplace; `tce`/`tmt` are the
  plugins installed as `<plugin>@toby-plugins`; the repo name matches the
  marketplace `name` by design.
- **Repository layout** — relocate the monorepo tree (`README.md:49-77`) and the
  "Adding another plugin is a new `plugins/<name>/` directory plus a
  `marketplace.json` entry" note, and the `${CLAUDE_PLUGIN_ROOT}` note
  (`README.md:75-76`). May trim to a concise tree and link to `CLAUDE.md`'s fuller
  "Layout" section.
- **Working on the plugins** — conventions a contributor needs, drawn from
  `CLAUDE.md` "Conventions": work directly on `main` (no branches/PRs strategy),
  conventional commits (what-not-how), never auto-push. Brief; point to `CLAUDE.md`
  for the full design rules (project-agnostic rule, composite-command tracking,
  the duplicated AskUserQuestion block, migrations).
- **Validating changes** — relocate the validate commands (`README.md:84-91`) and
  summarize `CLAUDE.md` "Testing changes": `claude plugin validate .` plus per
  plugin; scratch-project script smoke tests (e.g.
  `CLAUDE_PROJECT_DIR=/tmp/fakeproj plugins/tmt/scripts/next-ticket.sh`); end-to-end
  via `/plugin marketplace add .`.
- **Update gating** — relocate (`README.md:79-81`): updates are gated per plugin by
  its `version`.
- **Releasing** — relocate the release flow (`README.md:88-90` + `CLAUDE.md`
  "Releasing"): bump `version` in both the plugin's `plugin.json` and its
  `marketplace.json` entry, then `claude plugin tag ./plugins/<name>`; plugins are
  versioned/tagged independently and start at 1.0.0.
- **Design rules pointer** — a short "for the detailed design rules our tooling and
  reviewers enforce, see [`CLAUDE.md`](CLAUDE.md)" line, framed by audience (CLAUDE.md
  is written as agent instructions).

### Success Criteria:

#### Automated Verification:

- [ ] `CONTRIBUTING.md` exists at repo root: `test -f CONTRIBUTING.md`
- [ ] Repo still validates: `claude plugin validate .`
- [ ] No links to `TODO.md` in the file: `grep -c "TODO.md" CONTRIBUTING.md` returns 0

#### Manual Verification:

- [ ] All dev content from `README.md:35-91` is represented (two-names note, layout,
      update gating, validate, release).
- [ ] Tone is human-facing (not "you MUST" agent altitude); `CLAUDE.md` is referenced
      as the deep reference, not duplicated wholesale.
- [ ] The `CLAUDE.md` link resolves.

---

## Phase 2: Rework marketplace `README.md`

### Overview

Restructure the marketplace README value-first, remove the Development section now
living in `CONTRIBUTING.md`, and add a bottom Contributing link with License last.

### Changes Required:

#### 1. `README.md`

**File**: `README.md`
**Changes**: Target section order (value-first):

1. **H1** — keep `# toby-plugins` but drop rent-the-toby.com from the heading
   (currently `# toby-plugins — a Claude Code marketplace provided by
   rent-the-toby.com`, `README.md:1`). New H1 e.g. `# toby-plugins`.
2. **One-line tagline** (plain text, <120 chars) — category + capability, e.g. "A
   Claude Code plugin marketplace: a context-engineering workflow (`tce`) and a
   Git-tracked markdown ticket tracker (`tmt`)."
3. **Value section** — short "what you get / why" framing of the two plugins (can
   reuse the current intro lines `README.md:3-4`).
4. **rent-the-toby.com callout** (the agreed blockquote) — after the value section,
   before install.
5. **`## Plugins`** catalog table — preserve verbatim facts (`README.md:6-11`).
6. **`## Add the marketplace`** — preserve (`README.md:13-25`).
7. **`## Update`** — preserve (`README.md:27-33`).
8. **`## Contributing`** (new, near bottom) — one line linking
   `[CONTRIBUTING.md](CONTRIBUTING.md)`; the old `## Development` section and its
   subsections are removed (now in `CONTRIBUTING.md`).
9. **`## License`** — keep the "provided as-is" prose, as the **last** section.

### Success Criteria:

#### Automated Verification:

- [ ] No Development section remains: `grep -c "## Development" README.md` returns 0
- [ ] Contributing link present: `grep -c "CONTRIBUTING.md" README.md` >= 1
- [ ] rent-the-toby.com not in the H1 line: `head -1 README.md` contains no
      `rent-the-toby`
- [ ] Repo validates: `claude plugin validate .`

#### Manual Verification:

- [ ] Opening lines convey value before mechanics; callout sits after the value
      section, above install.
- [ ] Plugins catalog, add, and update facts are unchanged.
- [ ] License is the last section; Contributing link resolves to the new file.

---

## Phase 3: Rework `plugins/tce/README.md`

### Overview

Restructure tce value-first with the new heading, the callout, a TOC, and four
role-grouped command tables, preserving all usage content; add a bottom Contributing
link.

### Changes Required:

#### 1. `plugins/tce/README.md`

**File**: `plugins/tce/README.md`
**Changes**: Target structure:

1. **H1** — exactly `# tce — Toby Context Engineering` (replaces
   `plugins/tce/README.md:1`; rent-the-toby.com removed from heading).
2. **One-line tagline** — category + capability, e.g. "A context-engineering
   development workflow for Claude Code: ticket → research → plan → implement."
3. **Value section** — "what it is / why context engineering" (reuse the current
   intro `:3-26` and `## Why context engineering?` `:28-47`, condensed to lead with
   value; keep the blog link `:44-45` and the supersedes-template note `:20-26`).
4. **rent-the-toby.com callout** — after the value section, before the TOC/install.
5. **Table of contents** — links to the sections below (tce only).
6. **`## Requirements`** — preserve the tools table (`:48-61`).
7. **`## Install`** — preserve (`:63-69`).
8. **`## Set up a project`** — preserve, including the `/tce:init` walkthrough,
   the written-files tree, and the claude-template migration note (`:71-119`).
9. **`## Update`** — preserve (`:121-127`).
10. **`## Commands`** — replace the single Step-column table (`:133-146`) with four
    grouped tables, each preceded by a one-line intro, reusing each command's
    existing one-line purpose:
    - **Core workflow** (the ticket → research → plan → implement chain):
      `/tce:ticket`, `/tce:research`, `/tce:plan`, `/tce:implement`
    - **Shortcuts** (run the chain with less interaction): `/tce:work`,
      `/tce:quickfix`
    - **Helpers** (supporting commands): `/tce:discuss`, `/tce:review`,
      `/tce:commit`, `/tce:design_explore`
    - **Maintenance** (project setup & config): `/tce:init`, `/tce:refresh`
    Keep the profile-drift / `/tce:refresh` note that follows the table (`:148-153`).
11. **`## Agents`** — preserve the agents table (`:155-166`).
12. **`## How project parameterization works`** — preserve (`:168-185`).
13. **`## Contributing`** (new, bottom) — one line linking
    `[CONTRIBUTING.md](../../CONTRIBUTING.md)` (relative path from
    `plugins/tce/`).

### Success Criteria:

#### Automated Verification:

- [ ] Heading exact: `head -1 plugins/tce/README.md` equals
      `# tce — Toby Context Engineering`
- [ ] All 12 commands still referenced:
      `grep -oE "/tce:(ticket|research|plan|implement|work|quickfix|discuss|review|commit|design_explore|init|refresh)" plugins/tce/README.md | sort -u | wc -l`
      returns 12
- [ ] Contributing link present: `grep -c "../../CONTRIBUTING.md" plugins/tce/README.md` >= 1
- [ ] tce plugin validates: `claude plugin validate ./plugins/tce`

#### Manual Verification:

- [ ] Four grouped command tables in the agreed order; no Step column; every command
      keeps an accurate one-line purpose.
- [ ] Callout is after the value section; TOC links resolve to real headings.
- [ ] Requirements, Install, Set up (incl. migration note), Update, Agents, and How
      project parameterization works are all still present and accurate.

---

## Phase 4: Rework `plugins/tmt/README.md`

### Overview

Apply the value-first ordering and the callout to tmt, add a bottom Contributing
link; the heading is already correct.

### Changes Required:

#### 1. `plugins/tmt/README.md`

**File**: `plugins/tmt/README.md`
**Changes**:

1. **H1** — keep `# tmt — Toby Markdown Tickets` (`plugins/tmt/README.md:1`,
   already in target form).
2. **One-line tagline** — category + capability, e.g. "A lightweight,
   Git-tracked ticket tracker: every ticket is a markdown file in your repo."
   (reuse the current intro `:3-8`).
3. **Value section** — keep the "what you get" framing (`:16-33`) and the
   split-from-tce note (`:9-13`), leading with value.
4. **rent-the-toby.com callout** — after the value section, before install.
5. **`## Requirements`** — preserve (`:35-43`).
6. **`## Install`** — preserve (`:45-50`).
7. **`## Set up a project`** — preserve incl. migration notes (`:52-74`).
8. **`## Commands`** — keep the single 4-row table (`:78-83`); small enough that one
   table is appropriate (no regrouping).
9. **`## Ticket format`** — preserve (`:86-110`).
10. **`## Using tmt with tce`** — preserve (`:112-119`).
11. **`## Update`** — preserve (`:121-126`).
12. **`## Contributing`** (new, bottom) — one line linking
    `[CONTRIBUTING.md](../../CONTRIBUTING.md)`.

### Success Criteria:

#### Automated Verification:

- [ ] Heading unchanged: `head -1 plugins/tmt/README.md` equals
      `# tmt — Toby Markdown Tickets`
- [ ] Callout present: `grep -c "rent-the-toby.com" plugins/tmt/README.md` >= 1
- [ ] Contributing link present: `grep -c "../../CONTRIBUTING.md" plugins/tmt/README.md` >= 1
- [ ] tmt plugin validates: `claude plugin validate ./plugins/tmt`

#### Manual Verification:

- [ ] All four tmt commands, the requirements table, install/setup (incl. migration),
      ticket format, "Using tmt with tce", and update content are preserved.
- [ ] Callout sits after the value section; Contributing link resolves.

---

## Testing Strategy

### Automated (per profile.md):

- `claude plugin validate .`
- `claude plugin validate ./plugins/tce`
- `claude plugin validate ./plugins/tmt`

(These validate manifests, not README prose, but confirm no structural breakage.)

### Manual Testing Steps:

1. Render each README (GitHub preview or a markdown viewer) and confirm value lands
   in the first few lines, the callout is prominent but not in the H1, and headings
   flow value-first.
2. Click every cross-link: each README's bottom Contributing link → `CONTRIBUTING.md`;
   the marketplace ↔ plugin links; the `CLAUDE.md` link in CONTRIBUTING.md.
3. Diff old vs. new for each README to confirm no usage fact was dropped (commands,
   requirements, setup steps, migration notes, ticket format, agents).
4. Confirm the tce command tables list all 12 commands across the four groups with
   accurate one-line purposes.

## Migration Notes

None — documentation-only. No data, config, or version migration. Existing links
into these READMEs from elsewhere (e.g. `plugins/*/README.md` cross-links, the
`#install` anchor referenced in `README.md:21`) should be re-checked: if a section
heading whose anchor is linked changes, update the referring link in the same phase.

## References

- Original ticket: `thoughts/shared/tickets/TP-0011-readme-rework-user-first.md`
- Research: `thoughts/shared/research/2026-06-17-TP-0011-readme-rework-user-first.md`
- Dev rules to reference, not duplicate: `CLAUDE.md`
- Content to relocate: `README.md:35-91` (`## Development`)
- Current tce command table: `plugins/tce/README.md:133-146`
