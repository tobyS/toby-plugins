---
date: 2026-10-28T11:01:34Z
git_commit: dc13469327737e290d89d21d52035a550fc8c620
branch: main
repository: toby-plugins
topic: "TP-0045f: ticketless runs follow the branch convention and delivery"
tags: [research, codebase, tce, work-loop, quickfix, intent, branch-sh, delivery, ticketless]
status: complete
last_updated: 2026-10-28
---

# Research: TP-0045f — ticketless runs follow the branch convention and delivery

**Date**: 2026-10-28T11:01:34Z
**Git Commit**: dc13469327737e290d89d21d52035a550fc8c620
**Branch**: main
**Repository**: toby-plugins

Permalinks below point at commit `dc13469` on `main`. At the time of writing
`main` is 26 commits ahead of `origin/main`, so the links resolve once the
human pushes.

## Research Question

Ticket TP-0045f and its agreed intent
(`thoughts/shared/intents/2026-10-27-TP-0045f-ticketless-branch-and-delivery.md`):
ticketless runs — `/tce:quickfix`, and every step command or `/tce:work` given
a `ticket: none` intent path — should follow the profile's `## Branch
convention` and `## Delivery` exactly as ticket runs do. Under Branch per
ticket the branch name is the existing pattern with the intent's slug in
place of the ticket ID. Under Pull request delivery `/tce:quickfix` and a
ticketless `/tce:work` push and open the pull request with the dossier.
Current branch / Direct (or absent sections) must stay byte-identical to tce
1.5.0.

The intent's questions for research:

1. Where the ticketless branch is cut: the autonomous intent is the first
   artifact, but its slug is chosen inside `/tce:intent --autonomous`. Does
   quickfix cut the branch before or after it, and how does the base-branch
   stop-and-ask dialog reach the human from an autonomous step?
2. What the pull request title is without a ticket, and how a slug that is
   not a valid branch-name segment is handled.
3. Which TP-0031 span files and Delivery span files change, and whether
   `/tce:quickfix`'s `allowed-tools` needs `branch.sh`, `git push` and `gh pr`
   grants like `work.md`.

## Summary

The rule "ticketless never branches, always Direct" is encoded in a small,
well-defined set of places. The loop has two explicit ticketless overrides:
`work-loop.md` Step 2 skips the branch step at :116, and Step 10 forces
Direct at :243-244 and :259. `quickfix.md` restates the rule four times
(:16, the lane at :69-70, the Resuming paragraph at :83-87, and Rule 3 at
:95-96). Its `allowed-tools` (:5) carries no `branch.sh`, `git push` or `gh`.
`intent.md` restates it for both its interactive ticketless path
(:115-120) and Autonomous mode (:76-78, :431). The research, plan, implement
and work lanes carry no ticketless rule of their own; they inherit it from
`work-loop.md`. Documentation that states the rule lives in
`templates/tce/profile.md` (:75-78), `plugins/tce/README.md` (:223-227,
:234) and `CLAUDE.md` (:325, :328, :345-349, :396-398, :443-445).

Six mechanics bear on the change.

1. **Branch-name resolution happens in the commands, not in `branch.sh`.**
   The script receives a finished name, and only `create` validates it with
   `git check-ref-format --branch` (`branch.sh:134-135`, result
   `invalid-name`). The pattern has exactly two placeholders: `<ticket-id>`,
   and `<slug>` ("a short kebab-case slug of the ticket title").
2. **`/tce:intent` is the only `create` site.** It cuts the branch before the
   existing-intent lookup and before anything is written (`intent.md:134-137`).
   Step 2 of the loop only switches; `missing` means "no intent yet" and
   refuses (`work-loop.md:122-126`). The base-branch stop-and-ask dialog has
   exactly one verbatim copy, in `intent.md:139-154`.
3. **Autonomous mode chooses the slug at step 3, writes at step 4 and
   commits at step 5** (`intent.md:414-431`). The slug is therefore known
   before anything is written. Autonomous mode is specified as "Ask nothing"
   (`intent.md:396-398`).
4. **The loop's Entry reads the intent file by path before Step 2.** It greps
   the `ticket:` frontmatter (`work-loop.md:81-85`), and Step 1 reads the
   intent in full (:111-112). For ticket runs the ticket is read in Step 1 and
   the intent is found only after the Step 2 switch, by `stage.sh` in Step 3.
   For a ticketless run, the intent file is the argument itself.
5. **Pull-request delivery runs `gh pr create` with the title
   `"[PREFIX]-XXXX: <ticket title>"`** (`work-loop.md:252`). There is no
   ticketless title form. The dossier already has a ticketless heading form,
   `# Dossier: <slug> — [intent title]` (`dossier-template.md:41`), and the
   intent template's heading is `# Intent: [title]`
   (`intent-document-template.md:42`).
6. **Only `work.md` grants `git push`, `gh pr create` and `gh pr view`**
   (`work.md:5`). `quickfix.md:5` grants neither these nor `branch.sh`.
   `intent.md:4` grants `branch.sh`. Whether a Skill-invoked skill's
   `allowed-tools` apply inside the caller's turn is recorded as undocumented
   in earlier research.

## Detailed Findings

### 1. The loop: Entry, Steps 1–2, Step 10 (`plugins/tce/references/work-loop.md`)

**Entry (:76-88).**
- A ticket reference starts a ticket run.
- A path into `thoughts/shared/intents/` is opened, and its `ticket:` line is
  grepped. `none` makes the run ticketless: `<ID>` becomes the slug, and every
  payload carries `ticket: none`, `ticket-file: none` and `intent: <path>`
  (:81-85).
- This read happens on whatever branch the session is on, before Step 2.

**Step 1 (:107-112).** A ticket run reads the ticket. A ticketless run "read[s]
the intent now, fully, instead — it is the input".

**Step 2 (:114-127).**
- The first line is "Ticketless: skip this step entirely and print nothing."
  (:116). The profile is read only after it (:118).
- Under Branch per ticket the name is resolved from the pattern ("a `<slug>`
  element is a short kebab-case slug of the ticket title"), and
  `branch.sh switch <branch>` runs (:119-122).
- `switched` and `already` continue with one line naming the branch.
- `missing` refuses as in Step 3 point 2: "`/tce:intent` cuts the ticket branch
  before it writes the intent, so a missing branch means there is no intent
  yet, and `<command>` never cuts one itself" (:123-126).
- `dirty` asks the user to commit or stash; `blocked` reports `detail:` (:126-127).
- The step carries no copy of the base-branch dialog.

**Step 3 (:129-140).** `ticket.sh <ID>` and `stage.sh <ID>` run here. An empty
`intent:` line refuses. Ticketless runs get `parent: none` (:137).

**Step 10 (:241-266).**
- Opening rule: "Read the `## Delivery` section of `profile.md`. Ticketless:
  always Direct, whatever the section says." (:243-244)
- **Direct:** merge reference `direct: <branch> @ <short sha>` (:246-247).
- **Pull request** (:248-256):
  - base branch and remote come from the Branch convention;
  - `git push -u <remote> <branch>`;
  - `gh pr view <branch> --json url` reuses an existing PR's URL;
  - otherwise `gh pr create --base <base> --head <branch> --title "[PREFIX]-XXXX: <ticket title>" --body-file <dossier-path>` (:252);
  - a non-zero `gh pr view` because no PR exists "is the normal case";
  - any other failure is `blocked` with the last output line;
  - the merge reference is the PR URL.
- **No-delivery variant** (:258-261): "Direct (or ticketless) → merge reference
  `direct: …`; Pull request → merge reference `undelivered: <branch> @ <short
  sha>` (run `/tce:work <argument>` to deliver)."
- **Position row 1** (:263-266): deliver, rewrite the Closeout's Merge reference
  line, commit the plan via `/tce:commit`, `git push` again under Pull request,
  then re-derive.

**Step 11 (:268-289) and Step 12 (:291-313).**
- Ticketless runs skip the done transition (:284, :306).
- The Closeout Ticket line reads `none (ticketless intent)` (:278).
- The commit covers the plan only (:285).
- `git push` again under Pull request delivery (:286, :306-307) is conditioned
  on the Delivery value, not on ticket vs ticketless.

### 2. The position table (`plugins/tce/references/work-dispatch.md`)

- Row 1, "Closeout's Merge reference says `undelivered:` → delivery (Step 10),
  then rewrite … and re-derive", is first (:48). That is "because a closeout
  written by a lane without delivery carries both `undelivered:` and a final
  Manual verification value" (:59-61).
- The common block marks ticketless payloads (`ticket: … (or: none — a
  ticketless intent)`, :76) and says "With `ticket: none` the intent is the
  only input. The document ID is the intent's slug … `parent:` is always
  `none`" (:84-87).
- Only the researcher payload carries `branch: <current branch>` (:91-92).
  No other agent payload has a `branch:` field.

### 3. `/tce:quickfix` (`plugins/tce/commands/quickfix.md`)

- **Frontmatter `allowed-tools` (:5):** `ticket.sh`, `stage.sh`, `baseline.sh`,
  `work.sh`, `git rev-parse`, `git log`. There is no `branch.sh`, no
  `git push` and no `gh pr`.
- **:16:** "Nothing is branched, pushed or delivered."
- **Section 1 (:32-35):** runs `work-loop.md` Step 0 (preflight) "before
  anything is written".
- **Section 2 (:37-57):**
  - Skill-invokes `tce:intent --autonomous <description>`.
  - The last `intent:` / `insufficient:` line decides.
  - An `intent:` path is checked with `work.sh artifact` (exists / nonempty /
    committed).
  - Stops print fixed messages.
- **Section 3, the lane (:59-71):**
  - Start rows: all — "a fresh intent always starts at row 10".
  - Steps 5–12, with Step 6 "without the approval dialog" and Step 10 "in its
    *no delivery* variant".
- **Not-small stop (:73-81):** points to `/tce:work <intent path>`.
- **Resuming (:83-87):** every re-run line becomes `/tce:work <intent path>`,
  because a second `/tce:quickfix` would write a second intent. The paragraph
  then says: "For a ticketless intent `/tce:work` always delivers Direct, so it
  resumes exactly where this run stopped."
- **Rule 3 (:95-96):** "**Never branch, push or deliver** — ticketless work stays
  on the current branch; the human decides what happens next."

Combining two existing behaviours gives this: under Pull request delivery, the
quickfix lane's *no delivery* variant would write `undelivered:` only for a
ticket run, because ticketless is currently `direct:` (:259). Position row 1 of
a later `/tce:work <intent path>` keys on `undelivered:`.

### 4. `/tce:intent` (`plugins/tce/commands/intent.md`)

**Frontmatter (:4):** `allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh:*)`.

**Input classification (:74-97).**
- Autonomous mode is detected first and "skip[s] everything below … no
  dialogue, no branch step, no confirmation" (:76-78).
- The four interactive classes are:
  - (a) ticket reference;
  - (b) intent path;
  - (c) another `thoughts/` path, which becomes (a) when the user names a ticket (:95-96);
  - (d) free description, which is ticketless.

**"Put the ticket's branch in place (ticket intents only)" (:115-154).**
- It applies only to (a), or to (b) with a ticket. "If the section is absent,
  says **Current branch**, or this intent has no ticket, skip this step
  entirely" (:117-120).
- Name: the canonical ID substituted into the pattern, with `<slug>` "a short
  kebab-case slug of the ticket title" (:121-123).
- Command: `branch.sh create <branch> <base> <remote>` (:126).
- Results:
  - `created`, `switched`, `already` continue;
  - `fetch-failed` and `no-remote` stop and ask with the dialog, then re-run
    with `--trust-local` only after confirmation;
  - `dirty` asks;
  - `invalid-name`, `missing-base` and `blocked` report and stop (:129-133).
- Timing: "Do this **before** the existing-intent lookup and before anything is
  written or committed: the intent is the ticket's first artifact and lives on
  the ticket branch" (:134-137).
- The dialog is the one verbatim copy in the plugin (:139-154): an intro, the
  question "How should I proceed with the base branch?" with header "Base
  branch", and the options **Local tip is current** and **Stop here**.

**Existing intent lookup (:156-173).** For (c) and (d) it checks
`thoughts/shared/intents/*-<slug>.md` "for the slug you would use" (:163-164).
No other slug rule exists for the interactive ticketless path.

**Writing (:332-353).** Ticketless intents go to
`thoughts/shared/intents/YYYY-MM-DD-<slug>.md` (:345). The commit goes through
`/tce:commit` "with no ticket scope when ticketless" (:350-353).

**Autonomous mode (:394-433).**
- Output is exactly one line, `intent: <path>` or `insufficient: …`, and "Ask
  nothing and print no draft" (:396-398).
- "That line is your return value, not the end of the turn: … go straight back
  to its section '2. Intent'" (:401-403).
- The steps:
  1. Input (:405-408).
  2. Sufficiency (:409-413).
  3. **Slug** (:414-418): a short kebab-case slug; Glob
     `thoughts/shared/**/*<slug>*` and lengthen it until nothing matches.
     The glob sees only the files on the current checkout.
  4. **Write** (:419-428).
  5. **Commit** with `/tce:commit`, no ticket scope — "There is no branch
     step — ticketless work stays on the current branch." (:429-431).
  6. **Return** (:432-433).
- The slug is fixed at step 3, before the write at step 4.

### 5. `branch.sh` (`plugins/tce/scripts/branch.sh`)

- **Modes and callers (:7-21):**
  - `create <branch> <base> [<remote>] [--trust-local]` — "for /tce:intent";
  - `switch <branch>` — "for the step commands (work-loop.md) and /tce:review";
    never creates;
  - `check <branch> <base>` — "for /tce:commit"; no side effects.
- **Output contract (:27-37):** three lines (`branch:`, `result:`, `detail:`),
  exit 0 for every reported outcome. Results:
  - create: `created | switched | already | fetch-failed | no-remote | missing-base | dirty | blocked | invalid-name`;
  - switch: `switched | already | missing | dirty | blocked`;
  - check: `on-branch | on-base | elsewhere | detached`.
- **`create` (:130-163):**
  - `already` if HEAD is on the branch;
  - `invalid-name` via `git check-ref-format --branch` (:134-135);
  - if the branch exists locally or on `<remote>`, it switches to it
    (`switch_existing`, :137-139). An existing branch with the same name is
    therefore resumed, not refused;
  - `dirty` refuses;
  - `--trust-local` cuts from the local `<base>`;
  - no remote → `no-remote`;
  - fetch failure → `fetch-failed`;
  - otherwise cuts from `<remote>/<base>` with `--no-track`.
- **`switch` (:120-128):** `already`, or switch to a local or any
  `refs/remotes/*/<branch>`, or `missing` with the detail "branch $BRANCH does
  not exist; /tce:intent creates it" (:127).
- **`check` (:109-118):** compares only the current branch name with `<branch>`
  and `<base>`.
- The script is project-agnostic and receives every value as an argument
  (`lib.sh`'s `tce_project_root`, :75).

### 6. `/tce:commit`'s branch check (`plugins/tce/commands/commit.md` item h, :60-71)

- It applies "If the chat is about a ticket and the `## Branch convention` …
  says **Branch per ticket**".
- It resolves "the ticket's branch name from the recorded pattern" and runs
  `branch.sh check <branch> <base>`.
- `on-branch` continues silently. `on-base`, `elsewhere` or `detached` warn and
  ask in prose whether to commit anyway.
- "Skip this item when the section is absent, says **Current branch**, or the
  commit is not about a ticket." A ticketless commit is "not about a ticket" by
  that wording, so the check does not run for it.
- The check names no `<slug>` rule of its own.
- `commit.md` also says "**NEVER run `git push`**" (:100).

The step agents call `tce:commit` through the Skill tool. A branch-check
question from it is treated as `blocked` by the planner (`planner.md:148`) and
the implementer (`implementer.md:158`).

### 7. Lanes of the other step commands

- `research.md`, `plan.md` and `implement.md` carry no ticketless branch or
  delivery rule. They run `work-loop.md`, so Step 2's skip and Step 10's
  override apply to them.
- `implement.md:15-16`: "This command never pushes and never opens a pull
  request — `/tce:work` delivers." Its lane runs Step 10 in the *no delivery*
  variant (:45-46).
- research, plan and implement send position row 1 to `/tce:work <argument>`
  (research :43-45, plan :44-45, implement :48-49).
- `work.md`'s lane runs Steps 5–12 (:38-41) with no ticketless override.

`allowed-tools` per command (from the frontmatter lines):

| Command | branch.sh | git push | gh pr create / view |
|---|---|---|---|
| `work.md:5` | yes | yes | yes |
| `research.md:4` | yes | — | — |
| `plan.md:4` | yes | — | — |
| `implement.md:4` | yes | — | — |
| `quickfix.md:5` | — | — | — |
| `intent.md:4` | yes | — | — |
| `review.md:5` | yes | — | — |
| `commit.md:3` | yes | — | — |

### 8. The researcher's branch check (`plugins/tce/agents/researcher.md`)

- `branch:` is "the branch the work is on (the orchestrator has put it in
  place)" (:63).
- "If `git branch --show-current` does not equal `branch:`, return `blocked`
  without writing anything" (:70-71).
- The check makes no distinction for ticketless runs; `branch:` is whatever
  `work-dispatch.md:91-92` passes (`<current branch>`).
- The planner, implementer and verifier only carry the prohibition on
  creating or switching branches (`planner.md:27`, `implementer.md:28`,
  `verifier.md:27`).

### 9. Dossier and pull-request text

- `dossier-template.md`:
  - ticketless filename: `thoughts/shared/dossiers/YYYY-MM-DD-<slug>.md` (:33-35);
  - "It is committed on the branch the work is on. Under **Pull request**
    delivery its text is posted as-is as the pull request's body; otherwise
    /tce:work prints it." (:35-37);
  - ticketless heading: `# Dossier: <slug> — [intent title]` (:41).
- `intent-document-template.md:42` gives the intent heading `# Intent: [title]`.
- `verifier.md:142-145` writes the ticketless dossier path.
- The one PR-title template in the plugin is `work-loop.md:252`
  (`"[PREFIX]-XXXX: <ticket title>"`).

### 10. Profile template, init and refresh

- **`templates/tce/profile.md` Branch convention (:70-97):**
  - "Work without a ticket — ticketless intents and `/tce:quickfix`,
    discussions, design explorations, config, chores — and ticket *creation*
    are never moved: they stay on whatever branch the session is on."
    (:75-78)
  - The Branch name sub-field documents `<ticket-id>` and `<slug>` (:87-90).
  - :94 says "`/tce:research` creates the branch". `intent.md`, `branch.sh:11`
    and `:127`, and `CLAUDE.md` name `/tce:intent` as the create site.
- **Delivery (:99-118):** speaks of "a ticket's finished work" and "pushes the
  ticket branch"; it has no ticketless wording.
- **`init.md`:**
  - pattern dialog options `<ticket-id>`, `feature/<ticket-id>` and
    `<ticket-id>-<slug>` (:345-350);
  - under Current branch it fills Direct without asking ("a pull request needs
    a ticket branch", :360-361);
  - the allowlist excludes `git push` and `gh` (:596-597);
  - the Idempotency upgrade list (:643-693) has version-keyed bullets for
    1.1.0, 1.2.0, 1.3.0, 1.4.0 and 1.4.3.
- Neither `init.md` nor `refresh.md` contains the word "ticketless".
- `refresh.md` preserves Branch convention, Delivery and Reader as
  hand-authored.
- This repository's own `.claude/tce/profile.md` paraphrases the template's
  Branch convention prose, including "Work without a ticket (ticketless
  intents, `/tce:quickfix`) and ticket *creation* are never moved".

### 11. Consumer README and CLAUDE.md

- **`plugins/tce/README.md`:**
  - :223-227 — ticketless "documents are then named `YYYY-MM-DD-<slug>.md`, no
    branch is cut, no ticket is closed, and `/tce:work` delivers Direct";
  - :234 — the quickfix row says "no ticket, no branch, no delivery";
  - :395-402 — the Branch convention paragraph says "**Branch per ticket**
    makes `/tce:research` cut the ticket's branch … Non-ticket work and ticket
    creation are never moved. Only `/tce:work` under **Pull request** delivery
    pushes";
  - :404-410 — the Delivery paragraph.
- **`CLAUDE.md`:**
  - :325 — "Ticketless intents — including `--autonomous` ones — never branch."
  - :328 — "`/tce:quickfix` is always ticketless and skips it"
  - :345-349 — `/tce:quickfix` among the commands that "never branch —
    non-ticket work stays where the session is"
  - :396-398 — "only `/tce:work` delivers; `/tce:implement` records
    `undelivered:` under Pull request, and ticketless runs are always Direct"
  - :443-445 — "Pushing and `gh pr create` are granted only in `work.md`'s own
    `allowed-tools`, for delivery — the other lanes never deliver."
  - :480-490 — the "Ticketless naming" same-commit span.

### 12. Release state

- `plugins/tce/.claude-plugin/plugin.json:3` and `.claude-plugin/marketplace.json:15`
  both say `1.5.1` (TP-0045e's release, commit `4e88a20`).
- Tags `tce--v1.5.0` and `tce--v1.5.1` exist.
- The intent's byte-identity baseline names tce 1.5.0. 1.5.1 changed none of
  the TP-0045f anchors' branch or delivery text (see Historical Context).

### 13. Third-party behaviour (git, GitHub CLI)

- **`git check-ref-format --branch`** rejects:
  - a component starting with `.` or ending in `.lock`;
  - `..`;
  - control characters, space, `~ ^ : ? * [ \`;
  - a leading or trailing `/`, or `//`;
  - a trailing `.`;
  - `@{`, or the name `@`;
  - and, for `--branch` specifically, a leading `-`.

  A lowercase `[a-z0-9-]` slug not starting with `-` breaks none of these
  rules. Git documents no length limit. GitHub documents none officially;
  roughly 255 bytes is reported secondhand, unverified.
  ([git-check-ref-format](https://git-scm.com/docs/git-check-ref-format))
- **`gh pr create`:** `--head` "explicitly skip[s] any forking or pushing
  behavior". Non-interactively it fails without a title and body. If an open
  PR already exists for head into base it errors with `a pull request for
  branch "<head>" into branch "<base>" already exists` and exits 1.
  ([gh pr create](https://cli.github.com/manual/gh_pr_create),
  [create.go](https://github.com/cli/cli/blob/trunk/pkg/cmd/pr/create/create.go),
  [exit codes](https://cli.github.com/manual/gh_help_exit-codes))
- **`gh pr view <branch>`** with no PR returns `no pull requests found for
  branch "<branch>"` and exits 1. A branch lookup can also return closed or
  merged PRs (open ones first).
  ([gh pr view](https://cli.github.com/manual/gh_pr_view),
  [finder.go](https://github.com/cli/cli/blob/trunk/pkg/cmd/pr/shared/finder.go))
- **`git push -u`** adds the upstream tracking reference for each branch
  pushed successfully. ([git-push](https://git-scm.com/docs/git-push))

## Code References

- [plugins/tce/references/work-loop.md:81-85](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/references/work-loop.md#L81-L85) - Entry: the intent path's `ticket:` frontmatter is grepped before Step 2; ticketless `<ID>` = slug
- [plugins/tce/references/work-loop.md:111-112](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/references/work-loop.md#L111-L112) - Step 1: ticketless reads the intent in full
- [plugins/tce/references/work-loop.md:116](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/references/work-loop.md#L116) - Step 2: "Ticketless: skip this step entirely"
- [plugins/tce/references/work-loop.md:118-127](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/references/work-loop.md#L118-L127) - Step 2: name resolution, `branch.sh switch`, `missing` refuses
- [plugins/tce/references/work-loop.md:243-244](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/references/work-loop.md#L243-L244) - Step 10: "Ticketless: always Direct"
- [plugins/tce/references/work-loop.md:248-256](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/references/work-loop.md#L248-L256) - Pull request delivery: push, `gh pr view`, `gh pr create` with the `[PREFIX]-XXXX: <ticket title>` title
- [plugins/tce/references/work-loop.md:258-266](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/references/work-loop.md#L258-L266) - no-delivery variant ("Direct (or ticketless)") and the row-1 delivery path
- [plugins/tce/references/work-dispatch.md:48](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/references/work-dispatch.md#L48) - position row 1 (`undelivered:`)
- [plugins/tce/references/work-dispatch.md:84-92](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/references/work-dispatch.md#L84-L92) - ticketless common block; researcher's `branch: <current branch>`
- [plugins/tce/commands/quickfix.md:5](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/quickfix.md#L5) - `allowed-tools` without `branch.sh`, push or `gh`
- [plugins/tce/commands/quickfix.md:16](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/quickfix.md#L16) - "Nothing is branched, pushed or delivered."
- [plugins/tce/commands/quickfix.md:37-57](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/quickfix.md#L37-L57) - the Skill call to `tce:intent --autonomous` and its reading rule
- [plugins/tce/commands/quickfix.md:64-71](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/quickfix.md#L64-L71) - lane: Step 10 *no delivery*
- [plugins/tce/commands/quickfix.md:83-87](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/quickfix.md#L83-L87) - Resuming: depends on "`/tce:work` always delivers Direct"
- [plugins/tce/commands/quickfix.md:95-96](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/quickfix.md#L95-L96) - Rule 3: never branch, push or deliver
- [plugins/tce/commands/intent.md:4](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/intent.md#L4) - `allowed-tools`: `stage.sh`, `branch.sh`
- [plugins/tce/commands/intent.md:76-78](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/intent.md#L76-L78) - Autonomous mode: "no branch step"
- [plugins/tce/commands/intent.md:115-154](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/intent.md#L115-L154) - the branch step (ticket intents only) and the one verbatim base-branch dialog
- [plugins/tce/commands/intent.md:163-164](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/intent.md#L163-L164) - interactive ticketless slug lookup
- [plugins/tce/commands/intent.md:394-433](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/intent.md#L394-L433) - Autonomous mode steps (slug :414-418, write :419-428, commit + "no branch step" :429-431)
- [plugins/tce/scripts/branch.sh:7-37](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/scripts/branch.sh#L7-L37) - modes, callers, three-line contract
- [plugins/tce/scripts/branch.sh:130-163](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/scripts/branch.sh#L130-L163) - `create`: name validation, switch-if-exists, fetch, cut
- [plugins/tce/scripts/branch.sh:120-128](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/scripts/branch.sh#L120-L128) - `switch`: never creates; `missing` detail names `/tce:intent`
- [plugins/tce/commands/commit.md:60-71](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/commit.md#L60-L71) - item h): skipped when "the commit is not about a ticket"
- [plugins/tce/commands/work.md:5](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/commands/work.md#L5) - the only `git push` / `gh pr` grants
- [plugins/tce/agents/researcher.md:63-71](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/agents/researcher.md#L63-L71) - `branch:` check
- [plugins/tce/references/dossier-template.md:33-41](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/references/dossier-template.md#L33-L41) - ticketless dossier name, PR-body rule, ticketless heading
- [plugins/tce/templates/tce/profile.md:70-118](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/templates/tce/profile.md#L70-L118) - Branch convention (ticketless "never moved" :75-78) and Delivery
- [plugins/tce/README.md:223-234](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/README.md#L223-L234) - ticketless "no branch is cut … delivers Direct"; quickfix "no branch, no delivery"
- [plugins/tce/README.md:395-410](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/plugins/tce/README.md#L395-L410) - Branch convention and Delivery paragraphs
- [CLAUDE.md:325-349](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/CLAUDE.md#L325-L349) - TP-0031 span: ticketless never branch; quickfix skips Step 2; non-ticket work never branches
- [CLAUDE.md:396-398](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/CLAUDE.md#L396-L398) - Delivery readers: "ticketless runs are always Direct"
- [CLAUDE.md:443-445](https://github.com/tobyS/toby-plugins/blob/dc13469327737e290d89d21d52035a550fc8c620/CLAUDE.md#L443-L445) - push and `gh pr create` granted only in `work.md`

## Architecture Documentation

- **Division of labour for branching (TP-0031).**
  - Commands decide whether the convention applies, resolve the name, call
    `branch.sh` and act on its `result:` line.
  - The script does the git work and validates names only in `create`.
  - No raw `git switch` / `git fetch` grant exists in any command.
  - `CLAUDE.md`'s same-commit rule covers `branch.sh`'s modes and vocabulary
    together with `intent.md`, `work-loop.md`, `review.md` and `commit.md`.
- **One create site, one dialog copy.**
  - `/tce:intent` cuts the ticket branch before its first artifact.
  - The loop only switches and treats `missing` as "no intent".
  - The base-branch dialog lives once, in `intent.md`.
- **Orchestrator grants.**
  - Scripts run only in the orchestrator's turn; grants come from the running
    command's `allowed-tools` and last that turn.
  - Every loop dialog uses AskUserQuestion to stay inside the turn
    (`work-loop.md` invariant 5, :69-70).
  - Pushing and `gh pr` are granted per command; `/tce:init`'s allowlist
    excludes them.
- **Position on disk.**
  - Delivery state is the Closeout's Merge reference (`direct:`, a PR URL, or
    `undelivered:`).
  - Position row 1 makes `undelivered:` resumable by `/tce:work`.
- **Ticketless naming span.**
  - `ticket: none` marks a ticketless payload, and the slug is the document ID.
  - Discovery passes the bare slug to `stage.sh` / `ticket.sh` (delimited and
    substring matches respectively).
  - Autonomous mode's whole-`thoughts/shared/` glob is the only guard against
    slug collisions.
- **Absent-section guard.** "No section or Current branch → skip, print
  nothing" in every branch site is what keeps un-upgraded projects
  byte-identical (`CLAUDE.md` TP-0031 rule).

## Impact Analysis

### Existing Usages Found

`branch.sh create`:
- `intent.md:126` — the ticket branch for intent classes (a) and (b)-with-ticket.

`branch.sh switch`:
- `work-loop.md:122` — Step 2, for research, plan, implement and work;
  ticketless runs skip it at :116.
- `review.md:117-129` — ticket path only. Its `missing` text says
  "`/tce:research` creates it", while `branch.sh:127` says "/tce:intent creates
  it".

`branch.sh check`:
- `commit.md:63-64` — ticket-scoped commits only.

Pull-request delivery, `work-loop.md` Step 10:
- reached by the `work.md` lane, and by row 1 from `/tce:work`;
- `implement.md` and `quickfix.md` run the *no delivery* variant.

The researcher's `branch:` check:
- `researcher.md:70-71` — fed by `work-dispatch.md:91-92`.

### Current Contract

- **`branch.sh create <branch> <base> [<remote>] [--trust-local]`:**
  - receives a finished, unvalidated name and validates it with
    `git check-ref-format --branch`;
  - an existing local or remote branch of that name is switched to, not
    refused;
  - cuts only from `<remote>/<base>`, or from the local `<base>` with
    `--trust-local`.
- **`branch.sh switch <branch>`:** never creates; `missing` names
  `/tce:intent` as the creator.
- **Step 2 assumes that a branch exists whenever an intent exists**, because
  the intent's creator cuts it first. Ticketless runs skip Step 2, so this
  assumption holds today only for ticket runs.
- **The Entry assumes the intent path is readable from the session's current
  checkout** (:81-85). For a ticket run this needs only the ticket, read in
  Step 1; the intent is located after the switch.
- **Step 10's title template assumes a ticket ID and a ticket title.**
- **`commit.md` h) assumes that only ticket-scoped commits have a branch to
  check.**

### Adaptation Requirements

Where each existing assumption meets a ticketless branch:

- **`work-loop.md:116` and :243-244, :259:** the explicit ticketless overrides
  are the points where ticketless runs leave the Branch convention and
  Delivery path.
- **`work-loop.md:81-85`, :111-112:** a ticketless intent committed only on its
  own branch is not on disk while the session is on the base branch. The
  Entry and Step 1 read it before Step 2 runs.
- **`work-loop.md:119-121`:** the `<slug>` rule is "a short kebab-case slug of
  the ticket title". With the intent's slug in place of `<ticket-id>`, a
  `<ticket-id>-<slug>` pattern yields `<intent-slug>-<slug>`.
- **`intent.md:117-120`:** interactive ticketless intents (class d, and c
  without a ticket) skip the create step. A later `/tce:work <intent path>`
  whose Step 2 runs `switch` would get `missing`, which Step 2 treats as
  "no intent".
- **`intent.md:414-431`:**
  - The autonomous slug is fixed at step 3 and written at step 4. Placing a
    `create` between them puts the intent on the new branch.
  - The slug glob sees only the current checkout. A ticketless branch of the
    same name elsewhere, unmerged, is invisible to it, and `branch.sh create`
    would switch to that branch rather than refuse.
- **`intent.md:396-398`:** autonomous mode "Ask[s] nothing". The base-branch
  dialog (:139-154) is an AskUserQuestion dialog in the interactive path.
- **`quickfix.md:5`:** no `branch.sh`, `git push` or `gh pr` grant. The
  `branch.sh` call inside the Skill-invoked `tce:intent` runs under
  `intent.md:4`'s grant only if a Skill-invoked skill's `allowed-tools`
  apply in the caller's turn. Earlier research records this as undocumented
  (TP-0045c research :547-551; TP-0045e research :237-239, issue #67198).
- **`quickfix.md:83-87`:** the Resuming rationale rests on ticketless always
  being Direct.
- **`work-loop.md:252`:** the title is `[PREFIX]-XXXX: <ticket title>`. The
  ticketless analogues on disk are the intent's `# Intent: [title]` and the
  dossier's `# Dossier: <slug> — [intent title]`.
- **`commit.md:60-71`:** ticketless commits skip the branch check.
- **Docs:** `templates/tce/profile.md:75-78`, `README.md:223-227`, :234,
  :401-402, and `CLAUDE.md:325`, :328, :345-349, :396-398, :443-445.

### Backward Compatibility Options

Recorded as existing mechanisms, without choosing among them.

- **Option A — the absent-section guard.** Every branch site already skips
  when the section is absent or says Current branch, and every delivery site
  treats absent or Direct as Direct. Keyed off the profile instead of the
  ticketless flag, the same guards would leave Current branch / Direct
  behaviour identical.
  - Pros: no new mechanism.
  - Cons: each ticketless override (:116, :243-244, :259) has to be removed
    at the matching guard.
- **Option B — ticketless intents created before the change.** Existing
  ticketless intents under Branch per ticket were committed on the base
  branch, with no ticketless branch. Step 2's `missing` result for them is
  the case that differs.
  - Pros: the old documents stay findable on the base branch.
  - Cons: `switch` reports `missing` for them.

## Historical Context (from thoughts/)

- `thoughts/shared/intents/2026-10-17-TP-0045c-single-step-commands-on-agents.md:30-34`, `:108-110`, `:119-122`
  - "Without a ticket the branch step and the done transition are skipped,
    and delivery is always Direct"; quickfix "never branches and never
    delivers".
  - It is recorded as scope and acceptance criteria. No Decisions entry with
    a rejected alternative argues it.
- `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md`
  - :319 and :332 — the Step 2 / Step 10 ticketless substitutions;
  - :565 — "No branch step and no confirmation" for the autonomous intent;
  - :575-576 — quickfix gets "no `branch.sh`, no push";
  - :731 — the profile template wording;
  - :153 — the autonomous slug check uses Glob, not `ticket.sh`, because the
    grant during a Skill call is uncertain;
  - :651 — the resume-via-`/tce:work` rationale;
  - :875, :925 — the 2026-10-17 `fix-greeting-typo` quickfix run ended
    `direct: main @ ced1304`.
- `thoughts/shared/research/2026-10-17-TP-0045c-single-step-commands-on-agents.md`
  - :547-551 — Skill-invoked skill grant scoping is undocumented;
  - :57-66, :395-411 — slug-collision behaviour of `stage.sh` / `ticket.sh`.
- `thoughts/shared/plans/2026-09-05-TP-0031-declarable-branch-convention.md`
  - :123-125, :138-140, :432-434 — the origin of "non-ticket work stays where
    the session is": ticket creation stays on the base branch so tmt
    numbering stays shared. At the time `/tce:research` was the create site
    (:450, :968-972).
- `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md:140`
  - the decision that `/tce:intent` is the one `branch.sh create` site and the
    one dialog copy.
- `thoughts/shared/research/2026-10-11-TP-0045a-intent-reader-delivery.md:756-759`
  - "how ticketless work names … its branch is left to 45c".
- `thoughts/shared/intents/2026-10-27-TP-0045e-defects-from-stage-2-run.md:8`, `:35-36`
  and `thoughts/shared/plans/2026-10-27-TP-0045e-defects-from-stage-2-run.md:96`
  - ticketless branching and delivery moved out to TP-0045f.
  - TP-0045e changed only Step 0 of `work-loop.md`, the grant quoting
    (`13164b8`) and `quickfix.md` / `intent.md`'s return-line handling
    (`23f9183`, `494d4f2`, `intent.md:401-403`, `quickfix.md:43-46`). It did
    not change Step 2, Step 10 or the branch / delivery rules.
- `thoughts/shared/research/2026-10-27-TP-0045e-defects-from-stage-2-run.md:90-94`, `:205-215`, `:237-242`
  - a Skill call loads into the caller's turn (`intent.md` has no
    `context: fork`);
  - grants last one turn;
  - under `-p` from v2.1.302 an unmatched call is denied;
  - issue #67198: a grant applied to a typed invocation but not via the Skill
    tool;
  - grants do not reach subagents.
- `thoughts/shared/tickets/TP-0045f-ticketless-branch-and-delivery.md:19-20`, `:65-68`
  - the 2026-10-27 real quickfix run is recorded only here.

## Related Research

- `thoughts/shared/research/2026-09-03-TP-0031-declarable-branch-convention.md`
- `thoughts/shared/research/2026-10-11-TP-0045a-intent-reader-delivery.md`
- `thoughts/shared/research/2026-10-11-TP-0045b-step-agents-orchestrating-work.md`
- `thoughts/shared/research/2026-10-17-TP-0045c-single-step-commands-on-agents.md`
- `thoughts/shared/research/2026-10-27-TP-0045e-defects-from-stage-2-run.md`

## Open Questions

1. **Where does the ticketless branch get cut for `/tce:quickfix`?** Today
   `/tce:intent` is the only `create` site, and autonomous mode fixes its slug
   at step 3 before writing at step 4. The options visible in the code:
   - (a) autonomous mode runs `branch.sh create` between slug and write,
     mirroring the interactive ticket path;
   - (b) quickfix itself cuts the branch after the intent returns. The intent
     would then be committed on the base branch first, which acceptance
     criterion 1 excludes unless it is moved;
   - (c) quickfix pre-computes the slug.

   Which one keeps "the intent is the first artifact on the branch"?
2. **How does the base-branch stop-and-ask reach the human in an autonomous
   intent?** Autonomous mode is specified as "Ask nothing" and returns one
   line. Choices visible in the code:
   - (a) autonomous mode asks the existing verbatim dialog anyway. It runs
     inside quickfix's turn, so AskUserQuestion is available;
   - (b) it returns a new failure line (e.g. a third line kind beside
     `intent:` / `insufficient:`) and quickfix asks or stops;
   - (c) it stops the run with the `detail:` line, and the human updates the
     base and re-runs.

   Acceptance criterion 3 requires "stops and asks exactly as a ticket run
   does".
3. **Who creates the branch for an interactive ticketless intent** (`/tce:intent
   "<description>"`, classes c/d)? Today it never branches. Step 2's `switch`
   would report `missing` for it, which the loop reads as "no intent". The
   options: should interactive ticketless `/tce:intent` cut the branch like a
   ticket intent, or should the loop's Step 2 create for ticketless runs
   (which would make the loop a second `create` site and need the dialog
   there)?
4. **How does a ticketless run on the base branch read an intent that lives
   only on its branch?** The Entry (`work-loop.md:81-85`) and Step 1 read the
   intent by path before Step 2. Should the ticketless branch name be derived
   from the path's filename (the slug) and switched to before the file is
   read?
5. **What is the pull request title without a ticket?** Candidates on disk:
   - the intent's `# Intent:` title;
   - the dossier's `# Dossier: <slug> — [intent title]` heading;
   - the slug.
6. **How should `<slug>` in the branch pattern resolve for a ticketless run?**
   For example, `<ticket-id>-<slug>` would yield `<intent-slug>-<intent-title-slug>`.
   The intent only says the slug replaces `<ticket-id>`.
7. **What about a slug that is not a valid branch name, or collides with an
   existing branch?**
   - `branch.sh create` reports `invalid-name`.
   - An existing same-named branch (for example an unmerged ticketless branch
     from an earlier run, invisible to the slug glob) is switched to rather
     than refused.
   - Should autonomous mode's uniqueness check also cover branch names?
8. **Which grants does `/tce:quickfix` need?** For pushing and `gh pr`:
   quickfix runs Step 10 itself. For `branch.sh`: it depends on Open
   Question 1, and on whether `intent.md:4`'s grant applies during a Skill
   call from quickfix's turn, which is undocumented. Adding `git push` /
   `gh pr` to `quickfix.md` contradicts `CLAUDE.md:443-445` ("granted only in
   `work.md`'s own `allowed-tools`"). That rule's text would change with it.
9. **What happens to ticketless intents created before the change?** Under
   Branch per ticket these were committed on the base branch and have no
   branch. Should `/tce:work <old intent path>` then refuse (`missing`),
   create, or continue on the current branch?
10. **Should `/tce:commit`'s branch check (item h) cover ticketless commits?**
    Today it skips "the commit is not about a ticket", so a ticketless commit
    that lands on the base branch is not warned about.
