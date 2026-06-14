---
description: Re-analyze the project and reconcile .claude/tce/profile.md with it — proposes per-section changes, writes only what you approve.
---

# Refresh Project Config

You are tasked with bringing this project's tce config back in line with the actual
repository. Right now that means reconciling `.claude/tce/profile.md` (stack, commands,
code map) with what the repo really looks like, after the project has drifted — a
framework was added or swapped, the package manager changed, directories moved, a test
suite appeared.

**Do not write anything until the user approves** — analyze, propose per-section
changes, then write only what's approved. Never clobber hand-authored content.

## Project context

This command ships in the **tce** workflow plugin and is stack-agnostic. The project's
profile lives at `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`.

**Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` first.** If it's missing, this is a
fresh project — tell the user to run `/tce:init` (which *creates* the profile); `/tce:refresh`
only *updates* an existing one. Stop there.

**Scope:** this command currently reconciles `profile.md` only. The name is deliberately
generic so it can later cover other generated tce docs (e.g. `design-system.md`, the
`tickets.md` payload section); those are out of scope for now.

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

## Phase 1: Re-analyze the project

Investigate the repository fresh, the same way `/tce:init` does (keep this in step with
init's Phase 1 analysis targets — see the sync note in `CLAUDE.md`). Do it yourself with
Glob/Grep/Read/Bash; spawn the `codebase-locator`/`codebase-analyzer` agents only if the
project is large and the layout is unclear. Gather only the **factual** sections this
command refreshes:

1. **Tech stack & tooling** — look at manifests and lockfiles (`package.json`,
   `composer.json`, `go.mod`, `pyproject.toml`/`requirements.txt`, `Cargo.toml`,
   `Gemfile`, `pom.xml`, `build.gradle`, etc.): languages, frameworks, and the package
   manager actually in use.
2. **Commands** — derive the real **test**, **typecheck**, and **lint/format** commands
   from `package.json`/`composer.json` scripts, `Makefile`, `Taskfile`, CI config
   (`.github/workflows/*`), noting the directory each runs in.
3. **Code map** — monorepo vs single app, top-level apps/packages, and where each kind of
   code lives (entry points, business logic, models/schema, migrations, interface/UI/API,
   tests, config).

Do **not** re-derive **Conventions** or **Preferred research sources** from scratch —
those are hand-authored (see Phase 2).

## Phase 2: Compare, section by section

Read the existing `profile.md` and compare it to your analysis, one section at a time.
Classify the sections:

- **Factual (primary refresh targets):** `## Tech stack`, `## Commands`,
  `## Code map`. These are what re-analysis is authoritative about.
- **Hand-authored (preserved):** `## Conventions`, `## Preferred research sources`. Leave
  these untouched unless the user explicitly opts in to changing them.

Flag only **high-confidence** differences — concrete, observable mismatches, so the
proposal stays trustworthy:

- a manifest/lockfile shows a stack the profile doesn't mention (or vice versa);
- a test/typecheck/lint command recorded in the profile no longer exists in the repo;
- a code-map directory is gone, moved, or a clearly relevant new top-level area is absent.

Do not propose cosmetic rewording or low-confidence guesses. If a hand-authored section
seems contradicted by the code (e.g. a convention that no longer holds), you may *mention*
it as an observation, but do not change it without the user opting in.

If you find **no** high-confidence differences, report that the profile is already in sync
(quote the version, e.g. "profile is in sync — v[X.Y.Z]") and stop without writing.

## Phase 3: Propose per section, write on approval

For each factual section with a high-confidence difference, show a clear **before/after**
(a fenced block per section — there is no diff tool) and ask the user to approve that
section's change. Use the AskUserQuestion dialog guidelines above; batch the section
approvals into one call where it fits (one question per changed section, recommended
action first). Only offer to touch `## Conventions` / `## Preferred research sources` if
you have something concrete to suggest and the user opts in.

Then **write only the approved changes**, editing `profile.md` in place (use Edit — never
copy the template skeleton over it, which would clobber manual content). Preserve the
exact section structure and the sections the user didn't approve.

**Version marker:** read the installed plugin version from the `version` field of
`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` and compare it to the
`<!-- tce-config-version: X.Y.Z -->` HTML comment on line 1 of `profile.md`:

- **Same version** — leave the marker as-is.
- **Older or missing** — update it to the installed version as part of the write (a
  `profile.md` without the comment predates version markers; add it).

If the user approves nothing, change nothing and say so.

## Important

- **Never clobber.** Edit in place; preserve hand-authored sections and any section the
  user didn't approve.
- **Ask before writing** — every change is gated on approval.
- **Never touch anything under `thoughts/`** — that's the project's data.
- **No stack or ticket-system literals** — read project state; don't hardcode frameworks,
  commands, or paths beyond the standard `${CLAUDE_PROJECT_DIR}` / `${CLAUDE_PLUGIN_ROOT}`
  variables.
- Don't commit automatically — leave that to the user (or suggest `/tce:commit`).
