---
date: 2026-06-17T04:17:50Z
git_commit: 54541a68b868190f711fdc1471ac3b45e6eae97d
branch: main
repository: toby-plugins
topic: "Rework all READMEs into user-first docs and extract CONTRIBUTING.md (TP-0011)"
tags: [research, documentation, readme, contributing, marketplace, tce, tmt]
status: complete
last_updated: 2026-06-17
---

# Research: README rework into user-first docs + CONTRIBUTING.md extraction (TP-0011)

**Date**: 2026-06-17T04:17:50Z
**Git Commit**: 54541a68b868190f711fdc1471ac3b45e6eae97d
**Branch**: main
**Repository**: toby-plugins

## Research Question

For TP-0011: rework the three READMEs (`README.md`, `plugins/tce/README.md`,
`plugins/tmt/README.md`) into user-first, best-practice documentation; move all
"how to develop the plugin itself" content into a single repo-root
`CONTRIBUTING.md` linked from the bottom of each README; advertise
rent-the-toby.com high in each README (not in the heading); change the `tce`
heading to `tce — Toby Context Engineering`; and regroup the `tce` command
listing by importance/role. Document the current state of all docs and the
external best practices to apply.

## Summary

This is a **documentation-only** change. The repo currently has three READMEs and
no `CONTRIBUTING.md` or `LICENSE` file. The two plugin READMEs are nearly pure
usage docs already (good raw material) but lead with mechanics over value and
carry a few dev-flavored passages. The marketplace `README.md` is the main place
that mixes user docs with development content — it has an explicit `##
Development` section (repo layout, update gating, validate & release) that is the
primary thing to relocate into `CONTRIBUTING.md`. The deep development rules
already live in `CLAUDE.md`; best practice (and the ticket decision) is for
`CONTRIBUTING.md` to be a concise human-facing guide that **points to** `CLAUDE.md`
rather than duplicating it.

External research strongly converges on a value-first structure (title → one-line
category+capability tagline → promo callout → install → usage/command reference →
contributing link → license-last), supports either a single flat command table or
role-grouped tables for ~10–15 commands (grouping recommended when natural roles
exist — which is exactly the case here), and confirms the idiomatic patterns for a
maintainer/sponsor callout placed high but outside the H1 (blockquote under the
title block, the `sindresorhus/got` model).

The `tce` command set maps cleanly onto the four groups the ticket requested, with
**all 12 commands accounted for** — so the regrouping is complete and lossless.

No tce config drift found.

## Detailed Findings

### Current documentation inventory

| File | Role today | Lines | Notes |
|------|-----------|-------|-------|
| `README.md` | Marketplace catalog + dev | 95 | Has a `## Development` section (lines 35–91) that is the main content to extract. `## License` is a 2-line "provided as-is" (no LICENSE file). |
| `plugins/tce/README.md` | tce usage docs | 185 | Mostly usage. Heading carries rent-the-toby.com link (to change). A few conceptual sections ("Why context engineering?", "How project parameterization works"). |
| `plugins/tmt/README.md` | tmt usage docs | 126 | Pure usage. Heading already `tmt — Toby Markdown Tickets` (no change needed). |
| `CLAUDE.md` | Repo dev rules (agent-facing) | — | The authoritative internal design/dev reference; CONTRIBUTING.md should point here. |
| `TODO.md` | Maintainer backlog | 9 | Repo-level dev artifact (3 bullets). Not user-facing; belongs to the dev/contributor side, not a README. |

No `CONTRIBUTING.md` and no `LICENSE` file exist anywhere in the repo (confirmed via
`find`).

### Marketplace `README.md` — what is user-facing vs. development

User-facing (stays): the intro (lines 1–4), `## Plugins` catalog table (6–11),
`## Add the marketplace` (13–25), `## Update` (27–33).

Development (relocate to `CONTRIBUTING.md`):
- `## Development` heading + intro disclaimer — `README.md:35-39`
- "Two names, kept distinct" note + repo-location explanation — `README.md:40-47`
- `### Repository layout` (the monorepo tree) — `README.md:49-77`
- `### Update gating` — `README.md:79-81`
- `### Validate & release` (the validate + `claude plugin tag` block) — `README.md:84-91`

`## License` (`README.md:93-95`) is user-facing and per best practice should be the
**last** section; it stays (and should follow the new bottom-of-README Contributing
link, or sit adjacent to it).

### tce `README.md` — structure and the dev-flavored passages

Current heading: `# tce — context-engineering workflow for Claude Code by
rent-the-toby.com` (`plugins/tce/README.md:1`). Ticket requires exactly `tce —
Toby Context Engineering`, and the rent-the-toby.com reference moves out of the
heading into a high callout.

Current section flow: intro (1–26) → `## Why context engineering?` (28–47) → `##
Requirements` (48–61) → `## Install` (63–69) → `## Set up a project` (71–119) → `##
Update` (121–127) → `## Commands` (129–153) → `## Agents` (155–166) → `## How
project parameterization works` (168–185).

These are all **usage** content (confirmed against the README-vs-CONTRIBUTING split
— "how to use it" stays). "How project parameterization works" (168–185) explains
how the plugin adapts per project via `.claude/tce/` config — it is user-relevant
(it tells users they never edit the plugin), not contribution instructions, so it
stays in the README. Nothing in the tce README is contributor/dev-setup content
that belongs in CONTRIBUTING.md.

The current `## Commands` table (`plugins/tce/README.md:133-146`) uses a "Step"
column (setup / 1 / 2 / 3 / 3b / 4 / ✓ / — / ⚡) and lists commands in roughly
workflow order. The ticket asks to reorder by importance/role instead.

### tmt `README.md` — already close to target

Heading already matches the requested style (`# tmt — Toby Markdown Tickets`,
`plugins/tmt/README.md:1`). All sections are usage: `## What you get`, `##
Requirements`, `## Install`, `## Set up a project`, `## Commands`, `## Ticket
format`, `## Using tmt with tce`, `## Update`. No dev content to extract. Work here
is: add the rent-the-toby.com callout high, apply the best-practice ordering, and
add a bottom Contributing link. The heading carries no rent-the-toby.com link today
(it reads cleanly), so only the callout is added.

### tce command inventory and the requested 4-group mapping

Confirmed via `ls plugins/tce/commands/` — 12 commands. They map onto the ticket's
requested groups with full coverage:

| Group (ticket) | Commands | Files present |
|----------------|----------|---------------|
| Core chain | `ticket`, `research`, `plan`, `implement` | ticket.md, research.md, plan.md, implement.md |
| Shortcuts | `work`, `quickfix` | work.md, quickfix.md |
| Helpers | `discuss`, `review`, `commit`, `design_explore` | discuss.md, review.md, commit.md, design_explore.md |
| Maintenance | `init`, `refresh` | init.md, refresh.md |

All 12 files are accounted for (12 = 4 + 2 + 4 + 2). No orphan commands, no missing
ones. The current README's one-line purposes (`plugins/tce/README.md:133-146`) can
be reused per command; only the grouping/ordering and the dropped "Step" column
change. The 6 research agents (`plugins/tce/agents/`: codebase-analyzer,
codebase-locator, codebase-pattern-finder, thoughts-analyzer, thoughts-locator,
web-search-researcher) are documented in a separate `## Agents` table that already
exists and is usage content.

tmt has 4 commands (`create`, `init`, `list`, `update`) already in a single small
table (`plugins/tmt/README.md:78-83`) — small enough that one flat table remains
appropriate.

### Development content that exists for CONTRIBUTING.md to cover/reference

The dev knowledge is split between the marketplace README's `## Development` section
(to relocate) and `CLAUDE.md` (to reference, not duplicate). `CLAUDE.md` already
contains the authoritative sections a contributor needs:
- **Layout** (the plugins/ tree, how to add a plugin)
- **Core design rule: keep the plugins project-agnostic** (the no-literals rules,
  ownership boundary between tce and tmt)
- **Composite commands must track the single-step commands** + **refresh tracks
  init** + **AskUserQuestion block duplicated** — the cross-file invariants a
  contributor must respect
- **Testing changes** (`claude plugin validate`, scratch-project script testing)
- **Releasing** (version bump in plugin.json + marketplace.json, `claude plugin
  tag`)
- **Conventions** (work on `main`, conventional commits, no auto-push)

Per the ticket decision, `CONTRIBUTING.md` is a **concise human-facing guide** that
states the contributor essentials (how to propose a change, where things live at a
glance, how to validate locally, commit/branch conventions) and **points to
`CLAUDE.md`** for the deep design rules — framed by audience (CLAUDE.md is written
as agent instructions; CONTRIBUTING links to it as "the detailed design rules our
tooling and reviewers enforce").

`TODO.md` is a maintainer backlog (marketplace-wide). It is dev-side, not
user-facing; whether CONTRIBUTING.md references it is an open decision (see Open
Questions) — it is not currently linked from any README.

## Code References

- `README.md:1-33` — user-facing marketplace docs (intro, plugins table, add, update) — stays
- `README.md:35-91` — `## Development` section — **relocate to CONTRIBUTING.md**
- `README.md:93-95` — `## License` ("provided as-is", no LICENSE file) — stays, last
- `plugins/tce/README.md:1` — heading to change to `tce — Toby Context Engineering`
- `plugins/tce/README.md:133-146` — current `## Commands` table (Step column) — regroup by role
- `plugins/tce/README.md:155-166` — `## Agents` table — usage, stays
- `plugins/tce/README.md:168-185` — `## How project parameterization works` — usage, stays
- `plugins/tmt/README.md:1` — heading already in target form
- `plugins/tmt/README.md:78-83` — tmt commands table (4 commands) — single table fine
- `CLAUDE.md` — authoritative dev rules CONTRIBUTING.md references
- `TODO.md` — maintainer backlog (dev-side artifact)

## Architecture Documentation

Relevant repo conventions that constrain this doc work (from `CLAUDE.md` and
`.claude/tce/profile.md`):

- **Marketplace vs. plugin naming must stay distinct** — `toby-plugins` is the
  marketplace; `tce`/`tmt` are plugins installed as `<plugin>@toby-plugins`. The
  current marketplace README has a "Two names, kept distinct" note enforcing this;
  the rewrite must preserve that clarity (likely in CONTRIBUTING.md, since it's in
  the Development section today, but the README catalog must not muddy it).
- **Plugins stay project-agnostic** — no stack/ticket-system literals in plugin
  internals. This is a content rule for command/script files, not README prose, but
  README claims about "works with any ticket system" must stay accurate.
- **Releasing is per-plugin** — version bump in both `plugin.json` and the
  `marketplace.json` entry, then `claude plugin tag`. This is the validate & release
  content moving to CONTRIBUTING.md.
- **Work on `main`, conventional commits, never auto-push** — the contribution
  conventions CONTRIBUTING.md should state.
- **No build/test runtime** — "Test" is `claude plugin validate` (+ per-plugin) and
  scratch-project script smoke tests; there is no app build. CONTRIBUTING.md's
  "how to validate locally" reflects this (no `npm install`/build steps).

## External Best Practices (from web research)

### README structure (value-first)

Strong convergence (GitHub docs, Standard Readme, Make a README, markepear,
thoughtbot):

1. **Value-first opening** — H1 = name; then one plain-text line (<120 chars, no
   heading) stating **category + concrete capability**, not an abstract benefit.
   For dev tools, name the category ("a Claude Code plugin for…") then the concrete
   thing it does. Optionally a longer paragraph, then badges/visual.
2. **Section order**: title → tagline → (promo/sponsor callout) → badges/visual →
   TOC (required once long) → install → usage (with command reference) →
   reference/config → contributing (link) → **license last**. Standard Readme is
   strict that License is the final section and explicitly allows a CLI subsection
   inside Usage.
3. **README is the only docs here** → full usage + complete command reference
   legitimately stays inline (nowhere else to relocate to); only
   contributor/dev content splits out.
4. **Relocate, don't delete** — when a README is too long, move heavy material out
   (here: dev content → CONTRIBUTING.md) rather than cutting information.

### Documenting ~10–15 commands: flat table vs. grouped

Both are defensible; the deciding factor is whether commands fall into natural
roles. Examples: oclif auto-generates one **flat** commands table (peer commands);
`rdme` (ReadMe CLI) and Cloup group **namespaced/role clusters** with a short intro
per group. For 10–15 commands with natural roles, grouped tables/sections scan
better because the reader navigates by intent. **The tce commands have exactly such
roles** (core / shortcuts / helpers / maintenance), so grouped tables (each with a
one-line intro) is the supported choice — but the agent flagged this is a
synthesized recommendation, not a hard documented standard, so a single table with
sub-headers is also acceptable. Pair whichever with a TOC.

### Maintainer/sponsor callout placed high but outside the H1

Idiomatic pattern: a **blockquote callout immediately after the title/tagline block
and before install**, never in the H1. Canonical real example:
`sindresorhus/got` puts a sponsor blockquote under the logo, then a divider, then
the tagline/badges. A "Built by [maintainer] — [link]" line (cf. oclif's "Built by
Salesforce") is the common idiom for a maintainer's business/consulting. This maps
directly onto the agreed rent-the-toby.com blockquote in the ticket.

### README vs. CONTRIBUTING split

- **README (user-facing):** what/why, install, usage + command/API reference,
  config basics, where to get help, license, and a **link** to CONTRIBUTING.
- **CONTRIBUTING (contributor-facing):** how to report bugs / open PRs, local setup
  + how to run tests/validation, conventions, what contributions are wanted. GitHub
  auto-surfaces CONTRIBUTING.md as a "Contributing guidelines" link when someone
  opens an issue/PR.
- **Location:** repo **root** is the most discoverable for a small repo (precedence
  is `.github` > root > `docs` if multiple exist). Root matches the ticket decision.
- **Referencing CLAUDE.md is idiomatic** — the governing principle is "don't
  duplicate, link." Thin-pointer precedent: `codechecks/monorepo` CONTRIBUTING.md
  (~7 lines: welcome + issue-first + one validation command). For a repo with a deep
  internal doc already (CLAUDE.md), the thin human-facing CONTRIBUTING that points to
  it is the recommended model; frame the link by audience (CLAUDE.md reads as agent
  instructions).
- **README → CONTRIBUTING link**: a short "Contributing" section **near the bottom**
  of each README (matches the ticket's "linked from the very bottom").

### Linking from three READMEs to one root CONTRIBUTING.md

The two plugin READMEs live under `plugins/<name>/`, so their bottom link is a
relative `../../CONTRIBUTING.md`; the marketplace README links `CONTRIBUTING.md`.
(Mirrors how the plugin READMEs already cross-link, e.g. `../tmt/README.md`.)

## Historical Context (from thoughts/)

- `thoughts/shared/tickets/TP-0011-readme-rework-user-first.md` — the ticket itself
  (decisions recorded in Notes & Updates: one root CONTRIBUTING.md; human guide that
  points to CLAUDE.md; single shared rent-the-toby.com blurb, AI-workflow variant;
  tce heading + command grouping; complexity Medium).
- No prior research or plans reference README/docs structure (the discovery script
  returns only this ticket; earlier tickets TP-0001..TP-0010 are command/migration
  features, not docs).

## Related Research

None — this is the first docs-focused research document in `thoughts/shared/research/`.

## Open Questions

1. **Single grouped command layout vs. multiple tables** for tce — research supports
   grouped (the commands have clear roles); final form (one table with role
   sub-headers, or four small tables each with an intro line) is a planning/style
   decision. The ticket explicitly left this open.
2. **Drop the "Step" column?** The current tce table encodes workflow position
   (1→4, ⚡, ✓). Reordering by role loses the strict step numbering; planning should
   decide whether to keep a lightweight step/role indicator or rely on group
   headers + the existing "Why context engineering?" 4-step narrative.
3. **Exact placement of the rent-the-toby.com callout** in each README — under the
   tagline/intro and before install (the `got` model) is the researched default;
   confirm per README so it doesn't bury the value prop or quick start.
4. **Does CONTRIBUTING.md reference `TODO.md`?** TODO.md is a maintainer backlog; it
   could be mentioned as "known work" in CONTRIBUTING or left unlinked. Minor.
5. **Scope of CONTRIBUTING.md content** beyond relocating the marketplace
   Development section — how much of CLAUDE.md's contributor-relevant material
   (testing, releasing, conventions, the cross-file invariants) to restate briefly
   vs. link. Research favors thin-pointer; planning sets the exact line.
6. **README enhancements not in the ticket** (badges, TOC, demo/screenshot) — best
   practice suggests them, but they're additive and may be out of scope; planning
   should decide whether to add a TOC at minimum (recommended once a README is long).

## tce Config Drift

None found. `.claude/tce/profile.md` accurately describes the project (marketplace
monorepo, no app runtime/package manager, `claude plugin validate` as the test
command, the code map including "Consumer-facing docs | README.md (catalog),
plugins/*/README.md"), and `.claude/tce/tickets.md` correctly describes the tmt
backend, which matches the repo (`.claude/tmt/config`, `thoughts/shared/tickets/`).

## External Sources

README best practices:
- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes
- https://docs.github.com/en/repositories/creating-and-managing-repositories/best-practices-for-repositories
- https://github.com/RichardLitt/standard-readme/blob/main/spec.md
- https://www.makeareadme.com/
- https://github.com/matiassingers/awesome-readme
- https://github.com/othneildrew/Best-README-Template
- https://robots.thoughtbot.com/how-to-write-a-great-readme
- https://www.markepear.dev/blog/value-proposition-developer-tools
- https://github.com/oclif/example-multi-ts/blob/master/README.md (flat command table)
- https://github.com/readmeio/rdme (grouped/namespaced commands)
- https://github.com/sindresorhus/got (sponsor blockquote under title — promo placement model)
- https://github.com/oclif/oclif ("Built by Salesforce" maintainer line)
- https://docs.readme.com/rdmd/v1.2.0/docs/callouts (blockquote callouts)

CONTRIBUTING.md best practices:
- https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors
- https://opensource.guide/starting-a-project/
- https://opensource.guide/best-practices/
- https://contributing.md/how-to-build-contributing-md/
- https://github.com/codechecks/monorepo/blob/master/CONTRIBUTING.md (minimal thin-pointer example)
- https://github.com/executablebooks/.github/blob/master/CONTRIBUTING.md (comprehensive example)
- https://mozillascience.github.io/working-open-workshop/contributing/
