---
date: 2026-09-03T13:20:50Z
git_commit: a2087610b97ae2bbeda82aaf8c1bf9177eb3ac42
branch: main
repository: git@github.com:tobyS/toby-plugins.git
topic: "TP-0031: Let a project declare its branch model in the tce profile"
tags: [research, codebase, tce, profile, branch-convention, init, refresh, commit, research-command, baseline, composites]
status: complete
last_updated: 2026-09-03
---

# Research: TP-0031 — Let a project declare its branch model in the tce profile

**Date**: 2026-09-03T13:20:50Z
**Git Commit**: a2087610b97ae2bbeda82aaf8c1bf9177eb3ac42
**Branch**: main
**Repository**: git@github.com:tobyS/toby-plugins.git

## Research Question

TP-0031 asks for a `## Branch convention` section in `.claude/tce/profile.md`,
modelled on `## Commit convention`, that tce agrees at `/tce:init`, reconciles in
`/tce:refresh`, and follows at runtime — with "current branch" as the default
(today's behaviour, byte-identical when the section is absent) and "branch per
ticket" as the other option. The ticket's questions for research were:

1. Which commands need the branch step (research is certain; plan/implement/review
   unclear), and how each answer propagates into `/tce:work` and `/tce:quickfix`.
2. Where the shared logic lives — a `references/` file read at the point of use or
   a shipped `scripts/` helper like `baseline.sh`.
3. How the base branch is determined when the agent may have no network, and what
   "freshly updated" means when the human must perform the pull.
4. Where non-ticket commits (discussions, chores, config) go.
5. Whether `/tce:commit` should refuse a ticket-scoped commit on the base branch.
6. Whether the convention should also record the merge strategy.
7. The exact Idempotency mechanics in `/tce:init` and `/tce:refresh` for a profile
   that predates the section.

This document maps what exists today for each of these; it does not choose.

## Summary

- **No tce command creates, switches, or checks out a branch.** Git interaction is
  limited to recording metadata (`git rev-parse HEAD`, `git branch --show-current`,
  the remote URL) into thoughts documents, committing via `/tce:commit` (which never
  pushes), and `implement.md`'s baseline/diff mechanics. Five commands gather the
  current branch; only `research.md` and `review.md` persist it into a document; the
  research document's `branch:` field is named as an input by `implement.md:58` but
  no instruction anywhere acts on its value.
- **The `## Commit convention` mechanism the ticket wants copied is fully mapped**
  (TP-0008): a template section with an intro paragraph plus a bracketed all-options
  block (`templates/tce/profile.md:53-68`); an `/tce:init` Phase 1 gather item that only
  seeds a dialog default (`init.md:140-145`); a verbatim dialog site after the ticket
  dialogs (`init.md:258-278`); a Phase 3 Refine mention (`init.md:287`) and Phase 4
  fill instruction (`init.md:321-334`); a single runtime reader with an
  absent-section fallback equal to pre-feature behaviour (`commit.md:61-82`); a
  `/tce:refresh` Phase 1 item using the same heuristic plus a "factual" classification
  that flags only clear divergence (`refresh.md:79-105`); and README lines
  (`plugins/tce/README.md:157,165,222,265`). Every other command reaches the
  convention indirectly by delegating to `/tce:commit` or saying "per the project's
  commit convention (see profile.md)".
- **`/tce:research`'s ordering gap is as the ticket describes**: steps 1–4 are
  read-only, step 5 gathers `branch:` (`research.md:247-253`), step 6 writes the
  document, step 9 commits (`research.md:292-295`). Step numbers are cross-referenced
  from the research template (`research-document-template.md:9,41-43`) and within
  `research.md` itself, so inserting a step renumbers those references. `work.md`
  mirrors steps 5/6/7/9 as unnumbered bullets (`work.md:88-97`); `quickfix.md`
  mirrors them as Phase 3 items 4–6 (`quickfix.md:143-153`).
- **Two shared-logic homes exist with established conventions.** `references/`
  (two tce files, read "now — in full, even if you read it earlier in this session",
  each with a header comment naming its readers and its same-commit span) and
  `scripts/` (`baseline.sh` as the git-helper pattern: `set -e`, sources `lib.sh`,
  `cd "$(tce_project_root)"`, three-line stdout contract, exit 0 for every resolved
  outcome; pre-authorized per command via `allowed-tools`). `work.md` and
  `implement.md` are the only commands granting raw `git` verbs; `quickfix.md`,
  `discuss.md`, `design_explore.md`, `ticket.md` and `commit.md` declare no
  `allowed-tools` at all.
- **The Idempotency and refresh mechanics are precise and narrow.** `/tce:init`'s
  upgrade list has exactly two bullets (version marker; `## Dev environment`), an
  entry fires only when the marker differs from the installed version, and the
  version bump is decoupled from adding an entry. `/tce:refresh` has **no** handling
  for a section that is absent entirely and by design "does not define new required
  config". TP-0008's planned commit-convention upgrade bullet no longer exists after
  the 1.0.0 version reset.
- **Non-ticket work already has a defined path**: `commit.md:64-66` includes the
  ticket ID only "if the chat is about a ticket"; `discuss.md` and `design_explore.md`
  gather the branch but never commit; `init.md` and `refresh.md` never commit; a
  research document without a ticket omits the ID from its filename.
- **Externally**, `refs/remotes/origin/HEAD` is a local symbolic ref that only
  `git clone`, `git remote add -m`, `git remote set-head`, or (Git ≥ 2.48) a fetch
  that finds it missing will create; reading it needs no network. Ahead/behind
  counts are relative to the last fetch. `git switch -c` refuses an existing branch
  name; `git check-ref-format --branch` validates a generated name. Claude Code's
  `allowed-tools` grants are per-turn, substitute `${CLAUDE_PLUGIN_ROOT}` in Bash
  rules, and must match each subcommand of a chained command independently. Claude
  Code's own worktree feature is the platform's one built-in "default branch"
  notion (branches from `origin/HEAD`, falls back to local `HEAD`).
- This repository itself commits straight to `main` (`CLAUDE.md` Conventions,
  `CONTRIBUTING.md:66-67`); its profile has no branch statement; locally
  `refs/remotes/origin/HEAD` → `refs/remotes/origin/main`.

## Detailed Findings

### 1. The `## Commit convention` lifecycle (the shape to copy)

#### 1a. Template section — `plugins/tce/templates/tce/profile.md:53-68`

Verbatim:

```markdown
## Commit convention

How tce formats commit messages. `/tce:init` agrees this with you and fills in the
chosen convention's spec; `/tce:commit` (and the docs-commits in research / plan /
ticket / quickfix) read and follow it. The ticket-ID portion is resolved per
`.claude/tce/tickets.md` and is omitted when a commit isn't about a ticket.

[Filled by `/tce:init` with one of:

- **Conventional Commits** — `<type>(<ticket-id>): <description>` with an optional
  body. Types: feat, fix, refactor, docs, test, chore, style, perf, ci, build.
  First line under 72 chars; explain what/why, not how.
- **Plain / freeform** — `<ticket-id>: <description>` with an optional body.
  Imperative subject; first line under 72 chars; explain what/why, not how.
- **Issue-reference** — `#<ticket-id>: <description>` with an optional body. Intended
  for numeric issue trackers; first line under 72 chars; explain what/why, not how.]
```

Structure: an intro paragraph naming who fills it and who reads it, a blank line,
then one bracketed `[Filled by … one of: …]` block whose closing `]` sits on the
last bullet. Section order in the template (`profile.md:1-80`): version comment
(line 1) → `# Project Profile` + preamble → `## Tech stack` (9) → `## Commands`
(13) → `## Dev environment` (21) → `## Code map (where things live)` (30) →
`## Conventions` (48) → `## Commit convention` (53) → `## Preferred research
sources` (70). This repo's filled-in copy (`.claude/tce/profile.md:70-79`) keeps
the intro, edited to name the concrete ID form, followed by only the chosen bullet
with an example; it has no `## Dev environment` section (predates that addition)
and no branch statement.

#### 1b. `/tce:init` — detection, dialog, fill

- **Phase 1 gather item 9** (`init.md:140-145`) sniffs the last ~30 subjects
  (`git log --format=%s -n 30`) with two regexes to pre-select a default;
  "Empty or mixed history → default to Conventional Commits. This is only a
  suggestion." It is the last of nine gather items (`init.md:80-145`: stack,
  commands, layout, conventions, research sources, ticket system, existing setup,
  template install, commit convention).
- **Phase 2 dialog** (`init.md:258-278`) — third and last dialog, after the
  ticket-system dialog (`init.md:191-219`) and the two policy questions
  (`init.md:221-256`). Verbatim:

  ```
  Then ask about the **commit convention** with the AskUserQuestion tool, following the
  AskUserQuestion dialog guidelines (above). **Use this copy verbatim** — print the
  intro, then ask (move the convention detected in Phase 1 to position 1, append
  " (Recommended)" to its label, and note in its description that it matches the
  project's existing commits):

  ```
  How should tce format commit messages? It writes commits during the workflow
  (after research, planning, and each implementation phase), and /tce:commit follows
  this convention. It's recorded in .claude/tce/profile.md and you can change it there
  anytime.
  ```

  Question: "Which commit convention should tce use?" — header: "Commits", options:

  1. **Conventional Commits** — `type(ticket-id): description`, e.g. `feat(TP-0001): …`.
     Types: feat, fix, refactor, docs, test, chore, style, perf, ci, build.
  2. **Plain / freeform** — `ticket-id: description`, e.g. `TP-0001: …`. Imperative
     subject, no type prefix.
  3. **Issue-reference** — `#ticket-id: description`, e.g. `#123: …`. Best for numeric
     issue trackers like GitHub.
  ```

  The Phase 2 proposal block (`init.md:151-172`) does not list the commit
  convention; it surfaces only through the dialog. Phase 3 Refine (`init.md:286-288`)
  names "commit convention" among the things to adjust from feedback.
- **Phase 4 write** (`init.md:321-334`): files are written only after explicit
  confirmation (`init.md:13-14, 309`); the skeleton is copied with `cp`
  (`init.md:315-319`) and then every section is filled: "Tech stack, Commands, Code
  map, Conventions, Commit convention, and Preferred research sources"; the
  `tce-config-version` comment is stamped from the `version` field of
  `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` (`init.md:325-327`); `## Dev
  environment` is left at `[not set]`. For the commit convention: "replace the
  bracketed guidance with just the chosen convention's spec (one of the three
  blocks the template lists), keeping the intro paragraph above it. Use the
  canonical ticket-ID form for this project's ticket system" (`init.md:331-334`).
  Init never commits (`init.md:442`).

#### 1c. Runtime reader with fallback — `plugins/tce/commands/commit.md:59-82`

```markdown
Read the **`## Commit convention`** section of
`${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` and format the message exactly as it
specifies — the convention there governs the subject shape and where the ticket ID
goes. If the chat is about a ticket, include its canonical ticket ID (as defined in
`.claude/tce/tickets.md`, e.g. `MYAPP-0042`, `GH-123`) in the place the convention
prescribes; omit it when the commit isn't about a ticket. Regardless of convention:
```

and (`commit.md:73-82`):

```markdown
**If `profile.md` has no `## Commit convention` section** (older config, or no
profile), default to **Conventional Commits**:
```

followed by the pre-TP-0008 spec verbatim. `commit.md` has no `allowed-tools` and no
`disable-model-invocation` (delegation target). Docs-only vs code commit is decided
by file extension (`commit.md:25-28`: only `.md` files → skip tests/typecheck/lint).
`commit.md:86`: "**NEVER run `git push`**". A grep for `branch` and `main` in
`commit.md` returns nothing.

#### 1d. `/tce:refresh` — `plugins/tce/commands/refresh.md`

- Phase 1 item 5 (`refresh.md:79-84`) repeats init's heuristic word for word "the
  same way `/tce:init` Phase 1 does"; `refresh.md:86-88` carves out: "(The
  `## Commit convention` section *is* refreshed — it is distinct from the free-form
  `## Conventions` block.)"
- Phase 2 classification (`refresh.md:95-105`): **Factual** = `## Tech stack`,
  `## Commands`, `## Code map`, `## Commit convention`, and `tickets.md`'s backend
  adapter — "For `## Commit convention`, flag a difference only when the detected
  style clearly diverges from the recorded one; propose switching to the detected
  convention (re-using init's spec text)". **Hand-authored (preserved)** =
  `## Conventions`, `## Preferred research sources`, `tickets.md` policy choices and
  "What tce needs from a ticket".
- Phase 3 (`refresh.md:124-146`): before/after fenced block per changed section,
  batched AskUserQuestion ("one question per changed section, recommended action
  first"), Edit in place ("never copy a template skeleton over them"), version
  marker: "Same version — leave the marker as-is. Older or missing — update it to
  the installed version as part of the write" (`refresh.md:138-144`).
- **There is no passage for a section that is absent entirely.** The
  high-confidence-difference list (`refresh.md:110-115`) covers manifest/stack
  mismatches, vanished commands, moved directories, ticket-system mismatches and "a
  clearly relevant new top-level area is absent" (content-level). Refresh never
  commits (`refresh.md:157`) and the scope statement (`refresh.md:27-33`) excludes
  `design-system.md` and `## Dev environment`.

#### 1e. Documentation sites

- `plugins/tce/README.md:156-161` (Setup: "…conventions, and the **commit
  convention** tce should use — Conventional Commits, plain, or issue-reference,
  pre-selected from your git history…"), `:165` (profile.md tree line "stack,
  commands, conventions, commit convention"), `:222` (`/tce:commit` table row),
  `:230-237` (`/tce:refresh` paragraph — no explicit commit-convention mention),
  `:265-269` ("Stack, commands, conventions, commit convention — live in
  `.claude/tce/profile.md`"), `:270-275` (scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/…`,
  reference files Read at the moment of writing).
- Root `README.md` does not mention the commit convention or profile sections.

#### 1f. Other readers of the convention

| Location | Use |
|---|---|
| `ticket.md:242-245` | Creation-allowed path: docs-only commit "formatted per the project's commit convention (see `.claude/tce/profile.md`)" with a Conventional example |
| `implement.md:103`, `:224` | Log-block commit line; per-phase commit "formats the message per the project's commit convention (from `profile.md`)" |
| `implement.md:275-280` | Gate step 2 `git log --grep` fallback "only finds anything if the project's commit convention … puts the ticket ID in the commit message" |
| `quickfix.md:117-123`, `:148-153`, `:172-177`, `:220-225`, `:258` | Three docs-only commits "formatted per the project's commit convention (see profile.md)"; Final Summary note; Important Rule 4 |
| `work.md:97`, `:206`, `:238`, `:265` | Defers to `/tce:commit` at each commit point |
| `plugins/tle/agents/loop-implementer.md:12`, `:50` | Cross-plugin optional read: "Format the message per the `## Commit convention` section of `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` if that file exists; otherwise use Conventional Commits" |

No agent under `plugins/tce/agents/` and no reference file mentions the commit
convention.

### 2. Every branch touch point in tce today

| File:line | What happens with the branch |
|---|---|
| `research.md:252` | Step 5: `git branch --show-current` → research frontmatter `branch:` |
| `research.md:272-273` | Step 7: `git branch --show-current` and `git status` to decide whether to generate GitHub permalinks ("If on main/master or pushed") |
| `quickfix.md:143` | Phase 3 item 4: "Gather metadata using git commands (date, `git rev-parse HEAD`, `git branch --show-current`, repo URL)" |
| `work.md:88` | Phase 1b bullet "Gather git metadata" (unnumbered mirror of research step 5) |
| `review.md:272-278` | `### 1. Gather Metadata`: `date`, `git rev-parse HEAD`, `git branch --show-current` → review frontmatter `git_commit:`/`branch:` (`review.md:291-292`) and body (`:303-304`); files in `thoughts/shared/reviews/` |
| `review.md:134-146` | Ticket history via `git log --all --grep="[PREFIX]-XXXX"` (spans every ref) |
| `discuss.md:66` | "Gather metadata: `date +%Y-%m-%d`, `git branch --show-current`, `git rev-parse --short HEAD`" — the discussion template (`discuss.md:72-110`) has only `date`, `topic`, `status`; the branch is gathered but not stored; no commit step anywhere in `discuss.md` |
| `design_explore.md:294` | Same metadata line; `DECISION.md` frontmatter (`design_explore.md:299-305`) has `date`, `challenge`, `chosen-design`, `ticket`, `status` — no branch field; no commit step |
| `research-document-template.md:31`, `:43` | `branch: [Current branch name]` / `**Branch**: [Current branch name from step 5]` |
| `research-document-template.md:10-16` | Header comment: "implement.md reads `git_commit`/`branch`"; `git_commit` "is not guaranteed to stay reachable — if the work lands through a squash or rebase merge…" |
| `implement.md:58` | Repository state check: "The research document records the commit it was written at (`git_commit` and `branch` in its frontmatter)…" — then passes only `<git_commit>` to `baseline.sh`; `branch` is named but not used |
| `implement.md:124` | Closeout `**Merge reference**` rationale: "Where a project develops on branches that are squash- or rebase-merged and then deleted, those hashes stop resolving once the branch is gone" |
| `implement.md:264-284` | Gate step 2: baseline resolution; the `git log --grep` last resort notes "where changes reach the main branch as a single merged commit, that commit's own message has to carry it too" |
| `init.md:112-113` | Branch names appear only as a Jira-detection signal ("`KEY-123`-style uppercase ticket keys in recent commit messages or branch names") |
| `plan.md` | No git command at all (grep for `git` returns nothing); `plan-document-template.md` has no frontmatter and no git metadata fields |
| `ticket.md` | No git metadata gathering at all |
| `commit.md` | No reference to branches |
| `baseline.sh:60` | `git merge-base --is-ancestor "$RECORDED" HEAD` — the probe is always against HEAD; no base branch is named or detected anywhere in the plugin |

Cross-cutting: all metadata sites use the same commands; only research and
review persist the branch; `baseline.sh` takes a SHA and a document path, never a
branch. The `branch:` field is recorded but unused — TP-0030's research already noted
that "no instruction anywhere uses it" (see Historical Context).

### 3. `/tce:research` step ordering and its mirrors

**Section order before the numbered steps** (`research.md`): `## Ticket Document
Discovery` (88-112, with `### Parent / Epic Context`) → `## Ticket Sufficiency Check`
(114-133) → `## Initial Setup:` (135-154) → `## Steps to follow…` numbered 1–10
(156-304). `Initial Setup` step 1 (141-144) wires the order: "run Ticket Document
Discovery and the Ticket Sufficiency Check (above) first, then proceed with the
steps below". Frontmatter (`research.md:1-5`): `allowed-tools:
Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*)` only — the `git`/`date`/`gh`
commands in steps 5 and 7 are not pre-authorized.

**Steps 1–4** (158-245) are read-only: read mentioned files, decompose (TodoWrite),
spawn sub-agents, synthesize (incl. the config-drift check at 235-245). **Step 5**
(247-262) gathers metadata and fixes the filename. **Step 6** (264-268) reads the
template and writes the document. **Step 7** (270-276) permalinks. **Step 8**
(278-290) presents and prints `Next command`. **Step 9** (292-295) commits via
`/tce:commit`. **Step 10** (297-304) follow-ups, with a second commit at 304 (and,
per TP-0030's research, never refreshes `git_commit`).

**Step numbers are load-bearing cross-references**: `research-document-template.md:9`
("Step numbers below refer to /tce:research's numbered steps"), `:41-43` ("from
step 5"); within `research.md`: "step 6" (line 77), "step 4"/"step 8" (lines 84,
243-244), "step 5" (line 267), "step 4" (line 283).

**`work.md` Phase 1** (`work.md:65-99`): 1a is a numbered five-item list (resolve ID
→ `ticket.sh` → parent → sufficiency check → "Begin research immediately",
`work.md:69-77`); 1b is an unnumbered bullet list mirroring research steps 2–7
(`work.md:79-93`; "Gather git metadata" at 88, write at 89, permalinks at 90); 1c
commits via `/tce:commit` as docs-only (`work.md:95-99`) and explicitly drops step
8. `work.md:5` `allowed-tools`: `ticket.sh`, `baseline.sh`, `git diff`, `git
rev-parse` (no `git log`). Phase 4a item 2 (`work.md:225`) re-describes the state
check fast path and the later-session `baseline.sh` case; 4d (`work.md:256`) inlines
the gate.

**`quickfix.md`** (no `allowed-tools`, `quickfix.md:1-5`): Phase 3 items 1–6
(`quickfix.md:127-153`) mirror research — item 4 metadata (143), item 5 write (144,
reads the template), item 6 commit (148-153); no permalink step. Phase 2 item 1
invokes the `tce:ticket` skill (109-115) and item 2 commits the ticket for
file-based systems (117-123). Phase 4 invokes `tce:plan` (161) then commits
(172-177); Phase 5 invokes `tce:implement` (185) and inherits per-phase commits;
Phase 6 summary must name a non-recorded baseline (243-245); Rule 3 "Never push"
(257).

### 4. Commit points in chain order

| Step | Site | Scope |
|---|---|---|
| Ticket | `ticket.md:242-245` (interactive, file-based systems); `ticket.md:357` autonomous mode "the caller handles the commit" → `quickfix.md:117-123` | ticket-scoped by the ID in the subject |
| Research | `research.md:292-295` (step 9), `:304` (follow-ups); `work.md:95-97`; `quickfix.md:148-153` | docs-only |
| Plan | `plan.md:439-442` (Step 5 item 4, "Once the user is satisfied"); `work.md:204-206`; `quickfix.md:172-177` | docs-only |
| Implement | `implement.md:216-227` per verified phase (+ ticket file if status changed, `:222`); `work.md:238`; quickfix inherits | code |
| Review | `review.md:403`, `:412` — an *offer* to commit; `/tce:commit` not named | docs |
| Discuss / design_explore / init / refresh | never commit (`discuss.md`, `design_explore.md` have no commit step; `init.md:442`, `refresh.md:157` "Do not commit automatically") | — |

All commits route through `/tce:commit`, which reads no branch and never pushes.

### 5. Non-ticket work today

- `commit.md:64-66`: the ticket ID is included only "If the chat is about a
  ticket … omit it when the commit isn't about a ticket" — the condition is the
  conversation, not a branch name or an argument. The template intro repeats it
  (`templates/tce/profile.md:57-58`).
- `research.md:257`, `:262`: a research document without a ticket omits the ID from
  its filename (`YYYY-MM-DD-description.md`).
- `discuss.md` and `design_explore.md` produce documents without committing;
  `init.md` and `refresh.md` write config without committing; `ticket.md`'s
  copy/paste path (`ticket.md:256-257`) does not commit.
- Only `ticket.md` (Creation allowed path) and the four workflow commands commit with
  a ticket ID in scope.

### 6. Where shared logic lives today

#### 6a. `references/` (read at the point of use)

Two tce files: `research-document-template.md` and `plan-document-template.md`
(`plugins/tce/references/`); tle has `goal-file-template.md`. Both tce files open
with an HTML comment naming (a) who reads them and when ("Read at the moment of
writing a research document by /tce:research (step 6) and by the composite
commands' research phases (/tce:work, /tce:quickfix) — always in full, even if
already read earlier in the session. Never copied into consuming projects."), (b)
that changes are command-contract changes under the composite-tracking rule, (c)
downstream consumers, and (d) a `Contents:` list (`research-document-template.md:1-21`,
`plan-document-template.md:1-22`). The read instruction wording is uniform:
"Read `${CLAUDE_PLUGIN_ROOT}/references/….md` now — in full, even if you read it
earlier in this session" (`research.md:266`, `:341`; `plan.md:348`, `:397`;
`work.md:89`, `:197`; `quickfix.md:144`; `define.md:191`).

#### 6b. `scripts/` (shipped helpers)

`plugins/tce/scripts/`: `lib.sh`, `ticket.sh`, `baseline.sh`, `check-init.sh`.

- `lib.sh` (14 lines): one helper, `tce_project_root()` →
  `printf '%s\n' "${CLAUDE_PROJECT_DIR:-$PWD}"`; header states scripts "cannot
  assume their own location relates to the project".
- `ticket.sh` (34 lines): `set -e`; `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`;
  `# shellcheck source=lib.sh`; `. "$SCRIPT_DIR/lib.sh"`; usage on empty `$1`
  (`exit 1`); `find "$THOUGHTS_DIR" -type f -name "*${TICKET}*" | sort`.
- `baseline.sh` (94 lines) — the git-helper pattern. Contract (`baseline.sh:3-22`):
  `Usage: baseline.sh <recorded-sha> [<document-path>]`; prints exactly three lines
  `baseline: <sha>` / `source: recorded | introducing | none` / `detail: <one-line
  explanation the caller can report to the user>`; exit 0 for every resolved outcome
  including `none`; exit 1 only for usage error (both args empty) or "not a git
  repository"; `cd "$(tce_project_root)"` (39); shallow-clone note appended to
  `detail:` (53-56); step 1 reachability `git merge-base --is-ancestor` (58-70) with
  `git rev-parse --verify --quiet "${RECORDED}^{commit}"` only to word the
  diagnostic; step 2 three-tier introducing-commit lookup (`--first-parent
  --diff-filter=A`, then `--follow`, then `git rev-list HEAD -- "$DOC" | tail -1`,
  72-91), every lookup tested for an empty string because `git log` exits 0 when it
  matches nothing.
- Invocation wording in prose: `"${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh" <git_commit>
  <research-doc-path>` (`implement.md:58`), `… <base> <plan-path>` (`implement.md:266`,
  `work.md:256`); `"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-0001`
  (`research.md:97`, `plan.md:69`, `implement.md:49`, `review.md:118`, `work.md:74`).
- `hooks/hooks.json` references `check-init.sh` in exec form (see `CLAUDE.md`
  "userConfig" section).

#### 6c. `allowed-tools` today (every command file)

| Command | `allowed-tools` |
|---|---|
| `research.md:4` | `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*)` |
| `plan.md:4` | `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*)` |
| `review.md:5` | `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*)` |
| `implement.md:4` | `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh":*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*)` |
| `work.md:5` | `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh":*), Bash(git diff:*), Bash(git rev-parse:*)` |
| `quickfix.md`, `discuss.md`, `design_explore.md`, `ticket.md`, `commit.md`, `init.md`, `refresh.md` | none |
| tmt: `update.md:57`, `list.md:10`, `create.md:50` reference their scripts in prose | (see files) |

This repo's own dogfooding allowlist (`.claude/settings.local.json:11-12`, gitignored)
carries absolute-path entries for `ticket.sh` and `baseline.sh`, and `gh issue *` /
`gh pr *` (lines 21-22); it carries no `git` write verbs.

#### 6d. Governance-rule patterns in `CLAUDE.md`

The "same-commit span" paragraphs the ticket wants imitated: the composite-tracking
**RULE** ("Whenever you change a single-step command … check `work.md` and
`quickfix.md` and update them in the same commit if the change affects anything they
mirror"), the TP-0020 four-file gate span with its **RULE** paragraph, and the
TP-0030 baseline paragraph ("**the script joins the same-commit span above: change
the baseline mechanics and you update `baseline.sh`, `implement.md` and `work.md`
together.**" — the agent is explicitly excluded because it has no `Bash`). The
"refresh re-analysis must track init" section adds: "It reconciles existing config
but does **not** define new *required* config (that's init's Idempotency upgrade
list), so it needs no upgrade-list entry." The layout tree (`CLAUDE.md` Layout
block) and `CONTRIBUTING.md:41` list `scripts/` contents by name (`lib.sh,
ticket.sh …, baseline.sh, check-init.sh`).

### 7. `/tce:init` Idempotency and version markers

`init.md:444-477` verbatim core:

```markdown
Also compare the `tce-config-version` HTML comment at the top of `profile.md`
against the installed plugin version (`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`):

- **Same version** — report "tce config is already up to date (v[X.Y.Z])" and
  leave it alone (apart from any amendments agreed above).
- **Older or missing** — tell the user the config was written by an older tce
  (a `profile.md` without the comment predates version markers), walk through
  any config changes the newer version requires, and update the marker to the
  installed version. Ask before writing, as always. Today these are the
  changes to walk through:

  - A `profile.md` without the comment needs the version-marker comment line added.
  - A `profile.md` without a `## Dev environment` section (added for
    `/tce:design_explore`'s automated baseline capture) needs the section
    inserted, directly after `## Commands`, with its `[not set]` placeholder —
    never guess a URL.
```

- Exactly two bullets; each is detect-condition + what to insert + where +
  placeholder rule. There is **no** commit-convention bullet (TP-0008's plan added a
  `v3.2.0` bullet and bumped tce 3.1.0 → 3.2.0; the 1.0.0 reset for public launch
  removed it — `thoughts/shared/discussions/2026-06-17-reset-versioning-to-1.0-for-public-launch.md:113`
  records `## Commit convention` as "already in 1.0.0 templates").
- Upgrades are not per-item dialogs; they fold into the review-and-amend pass under
  the global no-writes-before-confirmation gate (TP-0003 plan:138-145).
- An entry fires only when the marker differs from the installed version; adding an
  entry without a version bump is inert for already-stamped projects (TP-0003
  plan:66-67, 90-91). `plugins/tce/.claude-plugin/plugin.json:3` is `1.0.1`; TP-0030
  recorded "no `tce-config-version` bump and no addition to" the list because it
  changed no project config (TP-0030 plan:114-115, 622-629).
- `thoughts/shared/` is never touched by any init path (TP-0003 plan:13-14, 84-86;
  `init.md:484-485`).
- The version-marker convention is documented in `CLAUDE.md` "Migrations & version
  markers (TP-0003)": "**If a new plugin version changes what the project config
  must contain, extend the init's Idempotency upgrade list in the same commit.**"

### 8. `implement.md`'s existing downstream assumptions

- `implement.md:58` (state check) and `:264-284` (gate step 2) both resolve a
  recorded SHA through `baseline.sh`; the same-session fast path skips it; `source:
  none` → no diff, blocking like "cannot verify".
- `implement.md:111-124`: the closeout template's `**Merge reference**` ("a
  pull/merge request number — or `n/a` when the project commits directly") exists
  because per-phase commit hashes "stop resolving once the branch is gone".
- Ticket status transitions (`implement.md:317-334`): `In Progress` when the first
  phase starts (ticket file joins the next commit), `Done` only after the gate and
  manual confirmations.
- `plan.md` performs no repository-state check: its only staleness signal is
  `last_updated` (`plan.md:101`).

### 9. This repository's own branch situation

- `CLAUDE.md` Conventions: "**Always work on `main`** — this project uses no
  branching or PR strategy." `CONTRIBUTING.md:66-67`: "**Work directly on `main`.**
  … don't create feature branches."
- `.claude/tce/profile.md` contains no branch statement (grep: no matches).
- Local git: `git symbolic-ref refs/remotes/origin/HEAD` → `refs/remotes/origin/main`;
  `git config --get init.defaultBranch` → `main`; remote `git@github.com:tobyS/toby-plugins.git`.

### 10. Git and Claude Code mechanics (external sources)

**Base branch without network.**
- `refs/remotes/<name>/HEAD` is a local symbolic ref; "Having a default branch for a
  remote is not required". It is created by `git clone`, `git remote add -m <branch>`,
  `git remote set-head <name> <branch>` (local) or `set-head -a` (network), and since
  Git 2.48 by a `git fetch` that finds it missing (`remote.<name>.followRemoteHEAD`,
  default `create`). Plain `git init` + `git remote add` + fetch on older Git leaves
  it absent. ([git-remote](https://git-scm.com/docs/git-remote),
  [Git 2.48 notes](https://raw.githubusercontent.com/git/git/master/Documentation/RelNotes/2.48.0.adoc),
  [GitHub blog](https://github.blog/open-source/git/highlights-from-git-2-48/))
- `git symbolic-ref refs/remotes/origin/HEAD` exits 0/1/128 (printed / not a symref /
  other error); when the ref is missing it dies with `fatal: No such ref` (128) even
  with `-q`. `--short` prints `origin/main`. ([git-symbolic-ref](https://git-scm.com/docs/git-symbolic-ref),
  [symbolic-ref.c](https://raw.githubusercontent.com/git/git/master/builtin/symbolic-ref.c))
- `git rev-parse --abbrev-ref origin/HEAD` resolves via gitrevisions rule 6
  (`refs/remotes/<refname>/HEAD`); `@{upstream}` resolves the *current branch's*
  upstream from `branch.<name>.remote`/`.merge` (`.merge` holds `refs/heads/main`,
  the remote-side name). ([gitrevisions](https://git-scm.com/docs/gitrevisions),
  [branch config](https://raw.githubusercontent.com/git/git/master/Documentation/config/branch.adoc))
- `init.defaultBranch` is user/global config consulted only at `git init`; it says
  nothing about an existing repository. ([git-init](https://git-scm.com/docs/git-init))
- Local-only: `git symbolic-ref`, `git rev-parse`, `git config`, `git remote` (list),
  `git remote show -n`. Network: `git remote show origin`, `git remote set-head -a`,
  `git ls-remote` (`--symref origin HEAD` reveals the remote default branch; exit 0
  on successful contact), `git fetch` (offline failures go through `die()` → exit
  128; `--dry-run` still contacts the remote). ([git-ls-remote](https://git-scm.com/docs/git-ls-remote),
  [usage.c](https://raw.githubusercontent.com/git/git/master/usage.c))

**Freshness without fetching.**
- Pro Git: remote-tracking branches move only on network communication; for
  `git branch -vv` "these numbers are only since the last time you fetched … If you
  want totally up to date ahead and behind numbers, you'll need to fetch".
  ([Pro Git, Remote Branches](https://git-scm.com/book/en/v2/Git-Branching-Remote-Branches))
- `git status --porcelain=v2 --branch` emits stable `# branch.upstream` and
  `# branch.ab +N -M` lines; `git rev-list --left-right --count main...origin/main`
  prints ahead/behind against the cached ref. ([git-status](https://git-scm.com/docs/git-status),
  [git-rev-list](https://git-scm.com/docs/git-rev-list))
- `.git/FETCH_HEAD` is written on every non-dry-run fetch (documented); using its
  mtime as "last fetch time" is community practice, not documented — the canonical
  StackOverflow thread was blocked for fetching, so claims that it is rewritten on
  failed fetches or absent right after clone are **unverified**. Reflogs for
  `refs/remotes/*` are on by default in non-bare repos but record only ref
  *changes*, so `git reflog show origin/main` answers "when did it last move", not
  "when did we last fetch". ([git-fetch](https://git-scm.com/docs/git-fetch),
  [core config](https://raw.githubusercontent.com/git/git/master/Documentation/config/core.adoc))

**Creating and switching.**
- `git switch -c <new> [<start-point>]` is "the transactional equivalent" of
  `git branch` + `git switch`; plain `-c` fails when the branch exists (`-C` resets
  it); switching aborts only when it would lose local changes — creating from HEAD
  with a dirty tree never conflicts. `--guess` (default) may auto-track a
  same-named remote branch. With `branch.autoSetupMerge` default, starting from
  `origin/main` sets upstream silently; starting from local `main` sets none.
  ([git-switch](https://git-scm.com/docs/git-switch), [git-branch](https://git-scm.com/docs/git-branch))
- `git branch --show-current` prints nothing on detached HEAD (exit 0).
- `git check-ref-format --branch <name>` validates a branch name (stricter than the
  ref form: no leading `-`); `feature/TP-0031` and `TP-0031-short-desc` are valid;
  slugs must avoid spaces, `~^:?*[\`, `..`, `@{`, trailing `.`/`/`/`.lock`.
  ([git-check-ref-format](https://git-scm.com/docs/git-check-ref-format))

**Claude Code.**
- `allowed-tools` "grants permission for the listed tools during the turn that
  invokes the skill … The grant clears when you send your next message"; it applies
  to plugin skills; `${CLAUDE_PLUGIN_ROOT}` is substituted in Bash rules of the
  frontmatter; documented example `allowed-tools: Bash(git add *) Bash(git commit *)
  Bash(git status *)`. ([slash-commands/skills](https://code.claude.com/docs/en/slash-commands))
- Permission matching: `Bash(git log *)` also matches bare `git log`; `:*` is an
  equivalent trailing wildcard; a rule "must match each subcommand independently"
  of `&&`, `||`, `;`, `|`, newlines. ([permissions](https://code.claude.com/docs/en/permissions))
- Claude Code's worktree feature is the platform's only built-in default-branch
  notion: `worktree.baseRef` `"fresh"` branches "from the repository's default
  branch on the remote, usually `main`"; it fetches the default branch when not
  fetched in 24h (5 s cap), uses the cached ref if the fetch fails, and "If no remote
  is configured, or `origin/HEAD` isn't cached locally and can't be fetched, the
  worktree falls back to your current local `HEAD`". Branch names cannot be
  configured as `baseRef`. ([worktrees](https://code.claude.com/docs/en/worktrees))
- CLAUDE.md docs carry no default-branch or branch-naming convention beyond generic
  examples ("Never push directly to main"). ([memory](https://code.claude.com/docs/en/memory))

## Impact Analysis

### Existing Usages Found

Code that a `## Branch convention` section would reuse or extend:

- `plugins/tce/templates/tce/profile.md:53-68` — the section shape (intro +
  bracketed options) being copied; `init.md:321-334` fills it; `refresh.md:95-101`
  reconciles it; `commit.md:61-82` reads it.
- `plugins/tce/commands/init.md:140-145`, `:258-278`, `:286-288`, `:321-334`,
  `:444-477` — gather item, dialog site, refine list, fill instruction, upgrade list.
- `plugins/tce/commands/refresh.md:79-88`, `:95-105`, `:138-144` — Phase 1 item,
  classification, marker.
- `plugins/tce/commands/research.md:247-295` and the step-number references at
  `research.md:77,84,243-244,267,283` and `research-document-template.md:9,41-43`.
- `plugins/tce/commands/work.md:69-99`, `:225`, `:5`; `quickfix.md:127-153`, `:1-5`.
- `plugins/tce/references/research-document-template.md:31,43` — the `branch:` field;
  its named consumer `implement.md:58`.
- `plugins/tce/commands/review.md:272-278`, `:291-292` — second persisted `branch:`.
- `plugins/tce/scripts/baseline.sh`, `lib.sh`, `ticket.sh` — script pattern;
  `implement.md:4`, `work.md:5` — allowlists.
- `plugins/tle/agents/loop-implementer.md:12,50` — cross-plugin optional reader of
  `## Commit convention` (the only reader outside tce).
- `CLAUDE.md` Layout tree, `CONTRIBUTING.md:41` — enumerate `scripts/` by filename.

### Current Contract

- **Profile section reading**: a consumer names the `## <Section>` heading, reads it
  from `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`, and states an explicit fallback
  for "no section / no profile" equal to pre-feature behaviour (`commit.md:73-82`).
  Sections are markdown prose; no parser exists.
- **Init dialog**: verbatim copy, detected option moved to position 1 with
  " (Recommended)", governed by the byte-identical guidelines block; written only
  after confirmation; template is the single source of truth for structure.
- **Refresh**: factual sections are re-detected and proposed only on clear
  divergence; hand-authored sections preserved; missing sections not handled;
  version marker maintained; no new required config defined.
- **Upgrade list**: bullets under "Today these are the changes to walk through",
  firing only when the marker differs from the installed `plugin.json` version.
- **Research frontmatter**: `branch:` is `git branch --show-current` at step 5;
  `implement.md:58` names it as an input but passes only `git_commit` on.
- **Scripts**: `Usage:` on empty args (exit 1), source `lib.sh`, `cd
  "$(tce_project_root)"`, plain-text stdout, exit 0 for every resolved outcome;
  invoked as `"${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh" <args>` and pre-authorized
  with `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh":*)` in each invoking command.
- **Step numbering**: `research.md`'s numbered steps are referenced by number from
  the research template and from within the command.

### Adaptation Requirements

- `templates/tce/profile.md` — a new section changes the template's section order
  and the list of sections `init.md:321-322` enumerates.
- `init.md` — a new gather item (Phase 1), a new dialog site (Phase 2), the Refine
  list (Phase 3), the fill instruction (Phase 4), and the Idempotency list would all
  need entries; `plugin.json` version and the marker semantics decide whether an
  upgrade entry ever fires.
- `refresh.md` — Phase 1 needs a detection item only if the section is classified
  factual; Phase 2 needs the section placed in one of the two classes; the absence
  of missing-section handling means "offer to add it" would be new behaviour for
  refresh, which today "does not define new required config" (`CLAUDE.md`).
- `research.md` — a step inserted before step 5 renumbers steps 5–10 and every
  cross-reference listed above (template and in-command); `work.md:79-93` and
  `quickfix.md:127-153` mirror the same sequence.
- `research.md:4`, `work.md:5`, `quickfix.md:1-5` — any git verb or script the branch
  step runs is unauthorized today in all three (research allows only `ticket.sh`;
  quickfix allows nothing).
- `implement.md:58` — the only place that names the `branch:` value; `plan.md` has no
  git step at all, so a branch check there would be entirely new surface.
- `commit.md` — reads no branch today; a refusal rule would be its first
  branch-aware behaviour and would affect every delegating command.
- `CLAUDE.md` Layout, `CONTRIBUTING.md:41`, `plugins/tce/README.md:270-275` — list
  scripts/references by name.
- `plugins/tle/agents/loop-implementer.md` — reads only `## Commit convention`; tle
  writes no project config and is not dogfooded here (`CLAUDE.md` intro).

### Backward Compatibility Options

- Absent-section fallback equal to today's behaviour (TP-0008's principle:
  `commit.md:73-82` keeps the pre-feature spec verbatim) means un-upgraded projects
  see no change; the ticket's acceptance criterion demands byte-identical output.
- Keeping the `branch:` frontmatter field name and position unchanged preserves
  `implement.md:58`'s read and the template's header comment.
- A step inserted into `research.md` can keep existing numbers if it is folded into
  an existing step (e.g. step 5) or placed as a lettered sub-step; a new top-level
  number requires updating every numeric cross-reference in the same commit.
- Version-marker semantics: an Idempotency entry becomes effective only after a
  `plugin.json` bump; without a bump, projects already stamped `1.0.1` never see the
  walk-through (TP-0003 plan:66-67, 90-91).

## Code References

- `plugins/tce/templates/tce/profile.md:53-68` — `## Commit convention` template section (intro + bracketed options)
- `plugins/tce/templates/tce/profile.md:1-80` — template section order
- `plugins/tce/commands/init.md:80-145` — Phase 1 gather items (item 9 = commit convention sniff, 140-145)
- `plugins/tce/commands/init.md:191-278` — Phase 2 dialogs (ticket system 191-219, policies 221-256, commit convention 258-278)
- `plugins/tce/commands/init.md:286-288` — Phase 3 Refine list
- `plugins/tce/commands/init.md:309-334` — Phase 4 write (cp skeletons 315-319; fill 321-334)
- `plugins/tce/commands/init.md:444-477` — Idempotency (upgrade list 462-466)
- `plugins/tce/commands/commit.md:25-28` — docs-only vs code commit
- `plugins/tce/commands/commit.md:59-82` — convention read (61-66) and fallback (73-82)
- `plugins/tce/commands/commit.md:86` — never push
- `plugins/tce/commands/refresh.md:55-88` — Phase 1 (commit convention item 79-84; carve-out 86-88)
- `plugins/tce/commands/refresh.md:90-122` — Phase 2 classification (95-105), difference list (110-115)
- `plugins/tce/commands/refresh.md:124-146` — Phase 3 proposals, write, version marker (138-144)
- `plugins/tce/commands/research.md:1-5` — frontmatter / allowed-tools
- `plugins/tce/commands/research.md:88-154` — Ticket Document Discovery, Sufficiency Check, Initial Setup
- `plugins/tce/commands/research.md:247-304` — steps 5–10 (metadata 247-262; write 264-268; permalinks 270-276; present 278-290; commit 292-295; follow-ups 297-304)
- `plugins/tce/references/research-document-template.md:1-21` — header comment (readers, consumers, `branch:` note)
- `plugins/tce/references/research-document-template.md:28-44` — frontmatter and body header
- `plugins/tce/references/plan-document-template.md:1-22` — header comment (no git metadata in plans)
- `plugins/tce/commands/plan.md:60-107` — discovery and research integration (no git)
- `plugins/tce/commands/plan.md:439-444` — commit and "job ends here"
- `plugins/tce/commands/implement.md:1-5` — allowed-tools
- `plugins/tce/commands/implement.md:58` — repository state check (names `branch`)
- `plugins/tce/commands/implement.md:95-135` — implementation log format, closeout (`**Merge reference**` 113-124), rules
- `plugins/tce/commands/implement.md:216-227` — committing each phase
- `plugins/tce/commands/implement.md:264-284` — gate step 2 diff mechanics
- `plugins/tce/commands/implement.md:317-334` — ticket status transitions
- `plugins/tce/commands/work.md:1-6` — allowed-tools
- `plugins/tce/commands/work.md:65-99` — Phase 1 (1a 69-77; 1b 79-93; 1c 95-99)
- `plugins/tce/commands/work.md:204-206`, `:225`, `:238`, `:256-257`, `:265` — plan commit, state check, phase commits, gate, rule 3
- `plugins/tce/commands/quickfix.md:1-5` — no allowed-tools
- `plugins/tce/commands/quickfix.md:97-123` — Phase 2 (ticket skill 109-115; commit 117-123)
- `plugins/tce/commands/quickfix.md:127-153` — Phase 3 (metadata 143; write 144; commit 148-153)
- `plugins/tce/commands/quickfix.md:157-196` — Phases 4–5 (plan/implement skills)
- `plugins/tce/commands/quickfix.md:243-245`, `:257-258` — baseline note; never push; commit convention rule
- `plugins/tce/commands/review.md:134-146` — `git log --all --grep` history
- `plugins/tce/commands/review.md:272-304` — metadata, frontmatter `branch:`
- `plugins/tce/commands/review.md:403`, `:412` — commit offer
- `plugins/tce/commands/discuss.md:66-112` — metadata, template without branch, no commit
- `plugins/tce/commands/design_explore.md:294-348` — metadata, DECISION.md frontmatter, no commit
- `plugins/tce/commands/ticket.md:242-245`, `:256-257`, `:357` — commit paths
- `plugins/tce/scripts/baseline.sh:1-94` — script contract and structure
- `plugins/tce/scripts/lib.sh:1-14` — `tce_project_root`
- `plugins/tce/scripts/ticket.sh:1-34` — script skeleton
- `plugins/tce/README.md:156-169`, `:222`, `:230-237`, `:265-275` — documentation sites
- `plugins/tce/.claude-plugin/plugin.json:3` — `"version": "1.0.1"`
- `plugins/tle/agents/loop-implementer.md:12`, `:50` — cross-plugin reader
- `CLAUDE.md` — Layout tree; Conventions ("Always work on `main`"); TP-0003, TP-0020, TP-0030 and refresh-tracks-init sections
- `CONTRIBUTING.md:41`, `:66-69` — scripts list; "Work directly on `main`"
- `.claude/tce/profile.md:70-79` — this repo's filled-in commit convention; no branch statement
- `.claude/settings.local.json:11-12`, `:21-22` — dogfood allowlist entries

## Architecture Documentation

- **Per-project config, markdown only.** All per-project data lives in the
  consuming project's `.claude/tce/` (markdown) and `.claude/tmt/config` (sourced
  shell); plugins coordinate only through those files. Profile sections are read by
  heading name at runtime; nothing parses them.
- **Preference sections follow one lifecycle**: template skeleton (source of truth
  for structure) → init gather item (seeds a default) → verbatim init dialog →
  Phase 4 fill (replace bracketed block, keep intro) → single runtime reader with a
  fallback equal to pre-feature behaviour → refresh classification (factual or
  hand-authored) → README + this repo's own profile (dogfood). TP-0008 is the
  complete precedent; TP-0010 (commit-frequency preference) is an unstarted second
  instance (status Open, no plan).
- **Two shared-logic homes**: `references/` for document templates read at the point
  of use (compaction-safe because re-read from disk), `scripts/` for git subtleties
  written once and referenced from every invoking command (TP-0030's reasoning:
  keeps decision trees out of both `implement.md` and `work.md`, at the cost of
  `allowed-tools` entries in each invoking command, a layout-tree line in
  `CLAUDE.md`/`CONTRIBUTING.md`, and a dogfood allowlist entry).
- **Composite tracking**: `work.md` re-describes research/plan/implement inline (its
  own numbered/bulleted mirrors); `quickfix.md` re-describes research inline but
  delegates ticket/plan/implement via the Skill tool. Delegation targets
  (`ticket`, `research`, `plan`, `implement`, `commit`) never carry
  `disable-model-invocation`.
- **Same-commit spans** are recorded in `CLAUDE.md` as named sections ending in a
  bold **RULE** paragraph listing the files that move together and, where relevant,
  which file is *excluded* and why (the compliance agent has no `Bash`).
- **Version markers**: `<!-- tce-config-version: X.Y.Z -->` on line 1 of
  `profile.md`; init stamps and compares, refresh maintains; required-content changes
  are init's upgrade list's job and become effective only after a `plugin.json` bump.
- **tce adapts to the repository, not the reverse** (TP-0030): no forge, host,
  branch-name or merge-strategy literal ships in plugin text; the closeout field is
  `**Merge reference**` rather than a PR number for that reason.

## Historical Context (from thoughts/)

- `thoughts/shared/tickets/TP-0008-configurable-commit-convention.md`,
  `thoughts/shared/research/2026-06-15-TP-0008-configurable-commit-convention.md`,
  `thoughts/shared/plans/2026-06-15-TP-0008-configurable-commit-convention.md` —
  the precedent being copied. Decisions: a dedicated named section, not folded into
  free-form `## Conventions` (research:98-106; plan:24-25); template carries every
  option's spec, init replaces only the bracketed block (plan:114-117, 210-213 —
  duplication between template and `commit.md` fallback accepted as "a small,
  documented sync point"); detection is dialog-seeding only ("a wrong guess is
  harmless", research:195-196); the dialog is a frozen contract (TP-0001); fallback
  = pre-feature behaviour verbatim (ticket:29; plan:87-93); **refresh scope flipped
  at the checkpoint** from "hand-authored, preserved" (research's recommendation,
  research:157-169) to "factual, reconciled" (plan:26-30) — the ticket had put refresh
  out of scope; ticket-ID placement belongs to each convention, no bare-number
  extraction (research:173-187); the planned `v3.2.0` Idempotency bullet no longer
  exists after the version reset; no `CLAUDE.md` edit was part of TP-0008.
- `thoughts/shared/tickets/TP-0030-drift-check-rewritten-history.md`,
  `thoughts/shared/research/2026-09-02-TP-0030-drift-check-rewritten-history.md`,
  `thoughts/shared/plans/2026-09-02-TP-0030-drift-check-rewritten-history.md` —
  motivating workflow "each ticket on a branch `gh-<n>`, squash-merge it into main,
  and delete the branch" (ticket:10-12); "Prescribing or changing any project's merge
  strategy — tce adapts to the repository, not the reverse" (ticket:99-100); script
  over prose because of compaction and the TP-0020 same-commit span (research:289-305;
  plan:119-125); reachability over existence (research:36-48, 222-238); `branch:`
  frontmatter "captured but never compared" (research:108-113, 522-524); the review
  "rejects worktree/parallel-branch machinery as 'not worth it'" (research:525-527);
  no branch name, forge or prefix shipped (plan:110-111, 553-554); no version bump
  because no project config changed (plan:114-115, 622-629); nothing in the three
  documents discusses a branch step, base-branch detection, or branch naming.
- `thoughts/shared/tickets/TP-0003-init-upgrade-migration.md`,
  `thoughts/shared/plans/2026-06-12-TP-0003-init-upgrade-migration.md` — marker
  compare/report/update; upgrades folded into the review-and-amend pass under the
  global confirmation gate (plan:138-145); "No version bumps / release tagging in
  this ticket (human decides releases; the marker mechanism reads whatever version
  is installed)" (plan:90-91); `thoughts/shared/` never touched (plan:13-14, 84-86).
- `thoughts/shared/tickets/TP-0004-profile-drift-refresh.md`,
  `thoughts/shared/research/2026-06-14-TP-0004-profile-drift-refresh.md`,
  `thoughts/shared/plans/2026-06-14-TP-0004-profile-drift-refresh.md` — factual vs
  hand-authored split (plan:90-92); per-section before/after approval (plan:93-96,
  101-103); "refresh updates an existing profile, it does not create one"
  (plan:78-79); "No Idempotency upgrade-list change is needed because refresh does
  not change what `profile.md` must contain" (plan:204-206); no statement about an
  entirely missing section.
- `thoughts/shared/tickets/TP-0010-init-commit-frequency-preference.md` — Open,
  Small, unstarted; the closest precedent for a second init preference dialog; it
  expects refresh to "preserve an existing value, can add it if missing" (ticket:44-46),
  an expectation nothing in `refresh.md` backs; flags the init↔refresh sync rule
  (ticket:66-68).
- `thoughts/shared/discussions/2026-06-17-reset-versioning-to-1.0-for-public-launch.md:113`
  — `## Commit convention` "already in 1.0.0 templates" (why no upgrade bullet
  survives).
- `thoughts/shared/tickets/TP-0013-explicit-context-document-reads.md`,
  `thoughts/shared/plans/2026-06-18-TP-0013-explicit-context-document-reads.md`;
  `thoughts/shared/tickets/TP-0020-plan-compliance-gate.md`,
  `thoughts/shared/plans/2026-07-05-TP-0020-plan-compliance-gate.md`;
  `thoughts/shared/tickets/TP-0022-sufficiency-criteria-sync-rule.md` — the re-read,
  gate-span and semantic-mirror governance rules cited by the ticket.
- The originating discussion the ticket cites
  (`thoughts/shared/discussions/2026-09-02-agent-feature-branch-workflow.md`) lives
  in the chat-sustainability project, not in this repository; it was not available
  to this research.

## Related Research

- `thoughts/shared/research/2026-06-15-TP-0008-configurable-commit-convention.md`
- `thoughts/shared/research/2026-09-02-TP-0030-drift-check-rewritten-history.md`
- `thoughts/shared/research/2026-06-14-TP-0004-profile-drift-refresh.md`
- `thoughts/shared/research/2026-06-12-TP-0003-init-upgrade-migration.md`
- `thoughts/shared/research/2026-06-12-TP-0001-askuserquestion-copy.md`
- `thoughts/shared/research/2026-06-16-TP-0009-implement-intermediate-commits.md`

## Open Questions

The ticket's questions, mapped to what research settled versus what remains a
decision for planning:

1. **Which commands get the branch step.** Facts: research is the first writer and
   committer (step 6/9); plan has no git step at all; implement already reads
   `branch:` from the research frontmatter (`implement.md:58`) but does nothing
   with it; review records its own `branch:`; discuss/design_explore never commit.
   Decision open: create-or-switch in research only, versus check-and-warn (or
   check-and-switch) in plan/implement/review; and whether `work.md` re-describes
   the step inline (as it does for research) while `quickfix.md` inherits plan/
   implement behaviour via Skill delegation but must mirror the research step in
   its own Phase 3.
2. **Shared-logic home.** Facts: both homes exist with clear conventions (§6). A
   `references/` file suits prose that several commands read at a moment of use;
   a `scripts/` helper suits git subtleties and gives one `allowed-tools` entry
   per invoking command instead of several raw git verbs. Decision open, including
   whether both are needed (a script for the git work, a reference for the
   rule prose), and the exact `allowed-tools` additions to `research.md`,
   `work.md` and `quickfix.md` (which today allow no git at all).
3. **Base branch offline.** Facts: `refs/remotes/origin/HEAD` is readable offline
   but not guaranteed to exist; `@{upstream}` describes the current branch, not the
   repository default; `init.defaultBranch` is irrelevant to an existing repo;
   ahead/behind counts are only as fresh as the last fetch, and "last fetch time"
   has no documented signal. The ticket's acceptance criterion already requires the
   profile to record the base branch explicitly, which sidesteps detection.
   Decision open: what "freshly updated" checks (a fetch attempt with a timeout, a
   human confirmation, or both) and what the stop-and-ask dialog says.
4. **Non-ticket commits.** Facts: today's rule is conversational ("if the chat is
   about a ticket") and discuss/design_explore/init/refresh never commit. Decision
   open: how the section states that non-ticket work stays on the current branch.
5. **`/tce:commit` refusal.** Facts: `commit.md` is branch-unaware and is the single
   delegation target for every commit point; the ticket lists enforcement as out of
   scope. Decision open.
6. **Merge strategy in the convention.** Facts: `baseline.sh` probes reachability
   against HEAD regardless of strategy; TP-0030 explicitly declined to prescribe or
   key on a merge strategy; no shipped text names one. Decision open.
7. **Idempotency mechanics.** Facts: two-bullet upgrade list; an entry fires only
   after a `plugin.json` bump; refresh has no missing-section path and by rule
   defines no new required config. Decision open: whether the section is a
   *required* section (upgrade bullet + version bump + marker) or an optional one
   (fallback only, like the missing commit-convention bullet today), and whether
   refresh classifies it factual (re-detected) or hand-authored (preserved) —
   TP-0008 flipped this at its checkpoint.

Additional unknowns surfaced by research:

8. Whether tle's `loop-implementer` (the only cross-plugin reader of a profile
   convention section) should read the branch convention at all; tle writes no
   project config and is not dogfooded here.
9. Which `research.md` step numbers change, given the cross-references from the
   research template and within the command, and how `work.md`'s unnumbered
   mirror and `quickfix.md`'s Phase 3 numbering follow.
10. The "freshly updated" check for the base branch relies on the unverified
    FETCH_HEAD-mtime heuristic if implemented offline; the canonical source was
    blocked for fetching.
