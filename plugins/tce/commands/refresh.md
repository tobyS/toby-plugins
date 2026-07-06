---
description: Re-analyze the project and reconcile .claude/tce/profile.md with it — proposes per-section changes, writes only what you approve.
disable-model-invocation: true
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

**Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` first** (and
`${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md`, whose backend adapter is refreshed too). If
`profile.md` is missing, this is a fresh project — tell the user to run `/tce:init` (which
*creates* the config); `/tce:refresh` only *updates* an existing one. Stop there.

**Scope:** this command reconciles `profile.md` (stack, commands, code map) and the backend
**adapter** in `tickets.md` (the factual, backend-derived parts: System / Canonical ID /
Reading / Parent-epic / Creating / Title-body layout / Status mechanisms). The ticket-system
**policy choices** (auto-update vs remind, creation allowed vs not) and the "What tce needs
from a ticket" section are hand-authored and preserved. `design-system.md` and the optional
`## Dev environment` section are not covered — the latter is hand-filled (by
`/tce:design_explore` or the user), not something re-analysis can verify against the repo.

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
4. **Ticket system & access** — re-detect the ticket system the same way `/tce:init`
   Phase 1 does (tmt config / `<PREFIX>-NNNN` files / GitHub remote + issue usage / Jira /
   Linear keys), and check that the access, create, and status mechanisms recorded in
   `tickets.md` still resolve (e.g. `.claude/tmt/config` still present for tmt; the recorded
   `gh`/CLI/MCP call still works). This re-derives only the **factual** adapter, never the
   policy choices.
5. **Commit convention** — sniff the project's commit style from history the same way
   `/tce:init` Phase 1 does: scan the last ~30 subjects (`git log --format=%s -n 30`); a
   majority matching `^\w+(\(.+\))?: ` → **Conventional Commits**, a majority matching
   `^#?\d+[: ]` → **Issue-reference (`#<ticket-number>`)**, otherwise **Plain / freeform**
   (empty/mixed → Conventional). This detects what the repo actually uses, to compare
   against the recorded `## Commit convention`.

Do **not** re-derive **Conventions** or **Preferred research sources** from scratch —
those are hand-authored (see Phase 2). (The `## Commit convention` section *is* refreshed —
it is distinct from the free-form `## Conventions` block.)

## Phase 2: Compare, section by section

Read the existing `profile.md` and compare it to your analysis, one section at a time.
Classify the sections:

- **Factual (primary refresh targets):** `profile.md`'s `## Tech stack`, `## Commands`,
  `## Code map`, `## Commit convention`, and `tickets.md`'s backend adapter (System,
  Canonical ticket ID, Reading, Parent/epic, Creating, Title/body layout, Status mechanism).
  These are what re-analysis is authoritative about. For `## Commit convention`, flag a
  difference only when the detected style clearly diverges from the recorded one; propose
  switching to the detected convention (re-using init's spec text), and on approval keep the
  ticket-ID placement in the canonical form for this project's ticket system.
- **Hand-authored (preserved):** `profile.md`'s `## Conventions` and `## Preferred research
  sources`, and `tickets.md`'s policy choices (auto-update vs remind, creation allowed vs
  not) and its "What tce needs from a ticket" section. Leave these untouched unless the user
  explicitly opts in to changing them.

Flag only **high-confidence** differences — concrete, observable mismatches, so the
proposal stays trustworthy:

- a manifest/lockfile shows a stack the profile doesn't mention (or vice versa);
- a test/typecheck/lint command recorded in the profile no longer exists in the repo;
- a code-map directory is gone, moved, or a clearly relevant new top-level area is absent;
- the ticket system recorded in `tickets.md` no longer matches reality (e.g. it says tmt but
  `.claude/tmt/config` is gone), or a recorded access/create/status mechanism no longer
  resolves.

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

Then **write only the approved changes**, editing `profile.md` and/or `tickets.md` in place
(use Edit — never copy a template skeleton over them, which would clobber manual content).
Preserve the exact section structure and the sections the user didn't approve — including
`tickets.md`'s policy choices and "What tce needs from a ticket".

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
