---
date: 2026-10-11T13:41:16Z
git_commit: 45f2e1ea2fe5651bd991fbf4fa8fde86b77fe4ef
branch: main
repository: toby-plugins
topic: "TP-0045a: /tce:intent, the intent file, and the Reader / Delivery profile sections"
tags: [research, tce, intent, ticket, profile, init, refresh, stage-sh, ticket-sh, list]
status: complete
last_updated: 2026-10-11
---

# Research: TP-0045a — `/tce:intent`, the intent file, `## Reader` and `## Delivery`

**Date**: 2026-10-11T13:41:16Z
**Git Commit**: 45f2e1ea2fe5651bd991fbf4fa8fde86b77fe4ef
**Branch**: main
**Repository**: toby-plugins

## Research Question

What does tce look like today in every place TP-0045a touches? The ticket
(`thoughts/shared/tickets/TP-0045a-intent-reader-delivery.md`, sub-ticket of
the TP-0045 epic) introduces five changes:

- a new file type, the **intent**, in `thoughts/shared/intents/`;
- a new unflagged `/tce:intent` command that runs `/tce:ticket`'s dialogue
  off the ticket;
- a rule that no tce command writes into an existing ticket's body;
- discovery of intents through `ticket.sh`, `stage.sh` and `/tce:list`;
- two hand-authored profile sections, `## Reader` and `## Delivery`,
  following the TP-0031 `## Branch convention` pattern.

The ticket lists five research questions:

1. the template's sections and how much of `ticket.md` moves;
2. how the two matchers pick up intents and how a ticketless intent is
   addressed;
3. which commands or habits fold content into tickets today;
4. the wording of the Reader prompt;
5. whether Delivery repeats the branch convention's remote and base.

The ticket passed the sufficiency check: scope, outcome and anchors are all
explicit. The epic has no research or plan documents of its own; its ticket
and the design discussion
`thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md` were
read as context.

## Summary

- **No intent infrastructure exists yet.**
  - There is no `thoughts/shared/intents/` directory.
  - `/tce:init` does not scaffold one. It creates
    `research plans reviews mockups discussions`
    (`plugins/tce/commands/init.md:451-461`; README tree at
    `plugins/tce/README.md:169`).
- **The dialogue to move is self-contained in `plugins/tce/commands/ticket.md`.**
  - Size assessment and track selection: `:96-118`.
  - Compressed two-round track: `:120-151`.
  - Full seven-phase track: `:153-225`.
  - Creating the ticket, through the `tickets.md` adapter: `:227-266`.
  - Ticket body skeleton: `:268-321`.
  - Guidelines: `:323-343`.
  - Autonomous mode, used by quickfix: `:345-360`.
  - The hand-off names `/tce:research` (`:58-59`, `:260-266`).
- **`ticket.sh` already finds intents; `stage.sh` does not.**
  - `ticket.sh` is a recursive substring `find` over all of `thoughts/`
    (`plugins/tce/scripts/ticket.sh:33`). It returns a file in
    `thoughts/shared/intents/` with no change.
  - `stage.sh` searches only `shared/research` and `shared/plans`
    (`plugins/tce/scripts/stage.sh:61-62`). It matches the ID as a delimited
    segment (`:93-95`) and prints a five-line record (`:284-288`).
  - `list.md` is that record's only consumer (`plugins/tce/commands/list.md:92`,
    `:98-104`). It renders Research and Plan as presence cells, `✓` or `–`
    (`:135`).
  - A ticketless intent (slug filename) is invisible to both scripts by
    construction.
- **No tce command writes into an existing ticket's body today.**
  - Body content is written only at creation, by `/tce:ticket`: interactive
    (`ticket.md:229-245`), the one-time override (`:253-258`), and autonomous
    for quickfix (`:352-358`).
  - After creation the only writes are status transitions: `implement.md`
    (`:335-347`), `work.md:284` and `commit.md:53-58`.
  - The ticket template's `## Implementation Plan` placeholder ("filled when
    the plan is created", `ticket.md:313-315`) is filled by no command.
  - Folding research and decisions into tickets happens as a session habit
    in this repo, not as a command instruction. Example: commit `1da6644`
    "docs(TP-0044): fold the research findings and decisions into the ticket"
    (+191/−40 lines on the ticket).
  - One prose suggestion exists: `design_explore.md:348`.
- **The sufficiency test has three copies.**
  - Canonical: `plugins/tce/templates/tce/tickets.md:85-111`.
  - Operational: `plugins/tce/commands/research.md:151-170`.
  - One-line compression: `plugins/tce/commands/work.md:102`. It is step 5,
    not 4 as CLAUDE.md says.
  - `research.md:169` says to record clarification answers "in the research
    document's context", but the research template has no section of that
    name.
- **The branch convention is the pattern to copy.** A full touch-point map is
  below:
  - template `profile.md:70-97`;
  - init gather item 10 (`:146-155`), two verbatim dialogs (`:290-335`),
    refine list (`:343-346`), fill (`:395-400`) and Idempotency 1.1.0 bullet
    (`:542-546`);
  - refresh's four "hand-authored" sites (`:27-36`, `:90-93`, `:108-111`,
    `:136-137`);
  - README `:274-284`;
  - every reader's absent-section guard.
  - The branch section already records **base branch** and **remote**
    (template `:89`). No profile section mentions pull requests, merging or
    pushing.
- **Versions.**
  - tce is at `1.2.0` in `plugins/tce/.claude-plugin/plugin.json:3` and
    `.claude-plugin/marketplace.json:15`.
  - Tags present: `tce--v1.0.0`, `tce--v1.0.1`, `tce--v1.2.0`. `tce--v1.1.0`
    is missing.
  - The dogfooded profile's marker is `1.2.0`. That profile has no
    `## Dev environment` section.

## Detailed Findings

### 1. `/tce:ticket` — the dialogue that moves to `/tce:intent`

File: `plugins/tce/commands/ticket.md` (360 lines; frontmatter `:1-4` has
`description` and `argument-hint: "[brief feature/bug description]"`, no
`allowed-tools`, no `disable-model-invocation`).

- **Framing.**
  - `:8-18`: WHAT and WHY, not HOW; the command owns ticket *content*, and the
    ticket system owns the *envelope*.
  - `:31-34`: "step 1 of the tce chain".
- **AskUserQuestion block**: `:36-54`. This is one of the twelve
  byte-identical copies listed in CLAUDE.md.
- **Modes** (`:56-66`):
  - interactive, scale-adaptive;
  - `--autonomous`, which skips the discussion.
- **Initial response** (`:70-94`):
  - reads `tickets.md` for the ID form, the creation mechanism and whether
    creation is allowed;
  - prints a "Heads up … doesn't permit me to create tickets" warning when it
    is not allowed (`:79-83`).
- **Size assessment & track selection** (`:96-118`):
  - estimate Small, Medium, Large or Extra Large with one line of reasoning;
  - Small/Medium → compressed track, Large/XL → full track;
  - the user can override, and asking for the full track always wins;
  - escalation switches to the full track in place.
- **Compressed track** (`:120-151`):
  - Round 1: restated understanding, estimate and a complete first-draft
    body;
  - Round 2: corrections, then "Ready for me to create this in [system]?";
  - business questions are exempt from the two-round cap.
- **Full track** (`:153-225`), seven phases:
  1. problem (gate);
  2. outcome (gate);
  3. stories;
  4. acceptance criteria (gate);
  5. boundaries and complexity, including XL splitting;
  6. open questions, split into business (resolve now) and technical
     (deferred to "Questions for Research/Planning");
  7. final confirmation.
- **Creating the ticket** (`:227-266`):
  - builds the body and persists it through the adapter;
  - docs-only commit, e.g. `docs([PREFIX]-XXXX): create ticket for …`
    (`:242-245`);
  - when creation is not allowed, a "Deliver" dialog offers copy/paste or
    "create it this once" (`:246-258`);
  - hand-off: `When ready, run: /tce:research [PREFIX]-XXXX` (`:260-266`).
- **Body skeleton** (`:275-321`), in this order: Estimated Complexity /
  Created / Updated; Problem Statement; Desired Outcome; User Stories;
  Acceptance Criteria; Out of Scope; Open Questions; Questions for
  Research/Planning; References; Implementation Plan ("Leave empty");
  Notes & Updates.
- **Guidelines 1-9** (`:323-343`). Guideline 9 is "Match ceremony to size".
- **Autonomous mode** (`:345-360`):
  - no discussion, Estimated Complexity Small;
  - "Open Questions: None — well-understood quickfix";
  - creates via the adapter and returns the ID;
  - the caller (quickfix) commits.

Inbound references to `/tce:ticket`:

- `quickfix.md:24`, `:100-116` (Skill-invokes `tce:ticket --autonomous`) and
  `:286`;
- `research.md:93` ("e.g. you just authored it via `/tce:ticket`");
- the workflow tables in `research.md:47`, `plan.md:47`, `implement.md:27`
  and `review.md:33`;
- `discuss.md:16` ("This is NOT: ticket creation");
- `init.md:514` (closing suggestion);
- `templates/tce/tickets.md:34,38,44,49,88`;
- `README.md:45-47` and `:205`.

`work.md` never invokes `/tce:ticket`, and `check-init.sh` does not name it.

### 2. Intent discovery — `ticket.sh`, `stage.sh`, `/tce:list`

**`ticket.sh`** (`plugins/tce/scripts/ticket.sh:33`):
`find "$THOUGHTS_DIR" -type f -name "*${TICKET}*" | sort`.

- It is recursive and directory-agnostic, matches on a substring, and returns
  absolute paths.
- An intent named `YYYY-MM-DD-[PREFIX]-XXXX-…md` in
  `thoughts/shared/intents/` appears in its output today.
- The substring match lets an epic claim its sub-tickets' files:
  `ticket.sh TP-0045` returns the epic and `TP-0045a…d`. A sub-ticket ID never
  matches its parent.
- Callers:
  - `research.md:131-137`, `:144`;
  - `plan.md:79-85`, `:92`;
  - `implement.md:59-65`, `:75`;
  - `review.md:131-134` (consumer `:136-143`);
  - `work.md:100-101`.
  - Each grants it in `allowed-tools`.

**`stage.sh`** (`plugins/tce/scripts/stage.sh`, 289 lines):

- **Input.** It takes ticket IDs as arguments and never reads tce config
  (`:5-10`).
- **Directories.** `RESEARCH_DIR` and `PLANS_DIR` are hard-coded (`:61-62`).
  The search is non-recursive (`:85`), and a missing directory returns empty
  (`:83`).
- **Match** (`:93-95`): `*-"$doc_id"-*|*-"$doc_id".md`, applied to the
  basename. The header explains why it is stricter than `ticket.sh`
  (`:66-69`).
- **Choice.** When several files match, the last one in glob order wins
  (`:71-73`, `:94`). Filenames are date-prefixed, so that is the newest.
- **Status files.** `skip-status` excludes `*.status.md` for plans (`:88-92`,
  `:253`).
- **Record** (`:284-288`, documented `:12-27`):

  ```
  ticket:   <id>
  research: <path relative to root, or empty>
  plan:     <path or empty>
  progress: <n/m, ?/m, or empty>
  source:   log | sidecar | unknown | no-plan
  ```

- **Fenced-code stripping** before heading matching: `:110-125`, `:184-199`.
- **Progress.** Derived from the plan's `### Implementation log` Status lines
  (`:104-163`), with a legacy sidecar fallback (`:180-242`).
- **Tests.** No committed tests or fixtures. TP-0033 verified it against this
  repo's corpus plus a transient `X-0100`/`X-0100a` fixture (plan
  `thoughts/shared/plans/2026-09-09-TP-0033-tce-list-workflow-stage.md:262-293`,
  `:877-887`).

**`/tce:list`** (`plugins/tce/commands/list.md`):

- **Grant.** `allowed-tools` grants only `stage.sh` (`:4`).
- **Call and parse.** It calls the script once with every ID (`:88-95`). The
  record is restated at `:98-104` and its `source:` semantics at `:106-112`.
- **Columns** (`:120-124`): `Ticket | Title | Priority | Status | Research |
  Plan | Implementation | Complexity`. Priority appears only when the adapter
  declares where priority lives; it does not here.
- **Cells.**
  - Research and Plan are `✓` when a path is reported, `–` otherwise (`:135`).
  - Implementation mapping: `:136-141`.
  - Epic rule (`:142-145`): an epic's Research and Plan cells show only its own
    documents.
- **Width constraints** (`:149-178`):
  - a real markdown table, never fenced or padded;
  - full-word headings;
  - glyphs limited to `✓`, `–`, `└─`;
  - every cell a word or two, because a too-wide table collapses into
    key/value cards.
- **Example table**: `:200-214`.
- **Rule.** `stage.sh`'s record and `list.md` change in the same commit
  (CLAUDE.md, TP-0033 section).

**Ticketless documents today.**

- Research and plan filenames omit the ID when there is no ticket
  (`research.md:291-299`, `plan.md:401-409`, e.g.
  `2024-12-04-authentication-flow.md`).
- Reviews use `YYYY-MM-DD-description-review.md` (`review.md:297-299`).
- Discussions use `YYYY-MM-DD-<slug>.md` (`discuss.md:66-68`).
- design_explore puts no ticket in the directory name and writes a
  `ticket: "[PREFIX]-XXXX (if applicable, otherwise omit)"` frontmatter field
  (`design_explore.md:303`).
- No command today takes a `thoughts/` *path* as the identity of a
  ticketless unit of work. `plan.md` accepts "path to ticket/plan file"
  (argument-hint) and `implement.md` accepts a "plan path".

### 3. Writes into tickets today

| Kind | Sites |
|---|---|
| Body at creation | `ticket.md:229-245` (interactive), `:253-258` (override), `:352-358` (autonomous) |
| Initial status + meta lines | `ticket.md:272-273` via the adapter |
| Status → In Progress | `implement.md:335-338` |
| Status → Done (after plan Closeout) | `implement.md:339-345`, `work.md:284` |
| Status in the pre-commit check | `commit.md:53-58`, `:103-104` |
| Status mechanism definition | `templates/tce/tickets.md:51-66`; `init.md:242-258` (policy dialog), `:416-417` (tmt fill), `:427-428` (GitHub fill) |
| Commit of a just-created ticket | `quickfix.md:118-123` |
| Suggestion only (no write by tce) | `design_explore.md:348` "suggest updating it with the design decision" |
| Explicitly read-only | `list.md:13`, `templates/tce/tickets.md:83` |

- **Checkboxes.** Every checkbox instruction targets the **plan**:
  `implement.md:197`, `:223`, `:323-324`, `work.md:267`, `:283`.
- **Acceptance criteria.** The ticket's criteria are only read, and extracted
  verbatim for the compliance gate (`implement.md:270-271`, `work.md:283`,
  `agents/plan-compliance-checker.md:16`).
- **The discussion's premise.** The 2026-10-09 discussion (`:108-110`) states
  that "the current `/tce:ticket` behaviour of replacing a real ticket's
  content pollutes other people's ticket systems". In the code, `/tce:ticket`
  only *creates* new tickets; it has no path that rewrites an existing ticket.
  The folding happens at session level: humans directing the model to "fold
  the research into the ticket", as in commit `1da6644` and the tsf-era
  `8400934` "align the tsf slice tickets with design v1.4".

### 4. The ticket-sufficiency test (TP-0022 span)

- **Canonical copy**: `plugins/tce/templates/tce/tickets.md:85-111`, "What tce
  needs from a ticket":
  - Clear scope, Observable outcome, An anchor (feature, screen, command,
    error message, or code area);
  - "Not required: business justification, formal acceptance criteria,
    technical detail, or any particular section structure";
  - optional sections that tce uses when present: Open Questions, Questions
    for Research/Planning, Acceptance Criteria (`:103-108`);
  - closing line: "Tickets missing the minimum trigger an upfront
    clarification round in `/tce:research` (and `/tce:work`)" (`:110-111`).
- **Operational copy**: `plugins/tce/commands/research.md:151-170`.
  - The three criteria are at `:158-160` and the not-required list at
    `:162-164`.
  - The action is one batched clarifying round per the AskUserQuestion
    guidelines, recorded "in the research document's context" (`:166-170`).
  - The check runs after Ticket Document Discovery (`:178-181`).
- **Compressed copy**: `plugins/tce/commands/work.md:102`, Phase 1a step 5.
  It names no recording location.
- `quickfix.md` has no sufficiency check.
- **Governance.** CLAUDE.md "The ticket-sufficiency criteria are triplicated"
  is a semantic-mirror rule, not byte-identical. It names `work.md` "Phase 1
  step 4"; the live position is step 5.

### 5. The TP-0013 ordered re-read sites

These are the sites where a one-line "if an intent exists, read it after the
ticket" would sit:

- `research.md:93`: the ticket is read FULLY in Discovery step 2.
- `plan.md:65`: "in chain order (ticket → research)". Also `:105` (research
  re-read) and `:185` (Step 1 input list).
- `implement.md:77-81`: a numbered list. Item 2 is the ticket (`:79`), item 3
  research, item 4 plan.
- `review.md:136-143`: a bullet list (ticket, research, plan, discussions).
- `work.md:73` (Phase 1a.1), `:219` (Phase 3a, "ticket → research"), `:251`
  (Phase 4a.1, "ticket → research → plan").
- `quickfix.md:134` (Phase 3.1). Planning and implementation inherit their
  reads through Skill delegation (`:191`, `:215`).

TP-0045b's ticket expects `research.md`, `plan.md`, `implement.md`,
`quickfix.md`, `review.md` and `commit.md` to stay untouched through 45b.
Whatever minimal edit 45a makes becomes 45b's baseline.

### 6. The branch-convention pattern (TP-0031) — every touch point

**Template** `plugins/tce/templates/tce/profile.md`:

- Line 1 is the version marker, `<!-- tce-config-version: FILLED-BY-INIT -->`.
- Section order:
  1. Tech stack `:9`
  2. Commands `:13`
  3. Dev environment `:21`
  4. Code map `:30`
  5. Conventions `:48`
  6. Commit convention `:53-68`
  7. Branch convention `:70-97`
  8. Preferred research sources `:99`
- Shape of an agreed section: an intro paragraph naming who fills and who
  reads it (`:72-77`), then a `[Filled by /tce:init with one of: …]` bracket
  holding one bullet per option (`:79-97`).
- The default option's bullet says "(The default — identical to leaving this
  section out.)" (`:82-83`).

**`init.md`**:

- **AskUserQuestion block**: `:16-34`.
- **Phase 1**:
  - gather item 9, commit convention sniff (`:140-145`);
  - gather item 10, branch: base-branch candidate from
    `git symbolic-ref refs/remotes/<remote>/HEAD` and model suggestion from
    merge history or ticket-named remote branches, "only a suggestion — a
    branch model is team policy" (`:146-155`).
- **Phase 2 dialogs, verbatim copy**:
  - commit (`:268-288`);
  - branch dialog 1 (`:290-311`): intro, question "Which branch model should
    tce follow?", header "Branches", two options, detected option first with
    a "Detected: …" prefix;
  - branch dialog 2, only for Branch per ticket (`:313-335`): name pattern and
    base branch.
- **Phase 3 refine list**: `:343-346`.
- **Phase 4**:
  - `cp` the template (`:374-377`);
  - fill-list sentence (`:379-388`);
  - commit fill (`:390-393`);
  - branch fill (`:395-400`): "replace the bracketed guidance with just the
    chosen model's bullet, keeping the intro paragraph above it".
- **Scaffold of `thoughts/shared/` subdirectories**: `:451-461`.
- **Idempotency** (`:519-564`):
  - Same version → "already up to date".
  - Older or missing → walk through the bullet list, update the marker, and
    ask before writing.
  - Current bullets: marker line (`:537`); Dev environment (`:538-541`); 1.1.0
    Branch convention (`:542-546`), quoted below; 1.2.0 `## Listing tickets`
    in `tickets.md` (`:547-553`).

    > A `profile.md` without a `## Branch convention` section (added in tce
    > 1.1.0) needs it inserted directly after `## Commit convention`. Do not
    > assume a model: run the branch-convention dialog from Phase 2 and fill the
    > section from the answer. **Current branch** is what the project
    > effectively had so far, so it is the safe answer when in doubt.

**`refresh.md`** — four sites name Branch convention as hand-authored:

- the Scope paragraph (`:27-36`): "a branch model is team policy, not
  something re-analysis can verify against the repo; `/tce:init` adds it when
  a profile predates it";
- the Phase 1 parenthetical (`:90-93`);
- the Phase 2 preserved list (`:108-111`);
- the Phase 3 "only offer to touch" list (`:136-137`).

The version marker is handled at `:144-150`. Refresh has no upgrade list, and
never adds a missing section.

**README** `plugins/tce/README.md`:

- the init description (`:156-162`);
- the `profile.md` tree comment (`:166`);
- the "How project parameterization works" bullet (`:274-284`);
- `:237-239`, which describes refresh as leaving "your hand-written
  Conventions and research sources untouched" and does not name Branch
  convention.

**Readers and the absent-section guard.** The representative wording, from
`plan.md:66-69`:

> If the section is absent or says **Current branch**, skip this item
> entirely: stay on the current branch and print nothing.

| File | Grant | Reader site | Note |
|---|---|---|---|
| `research.md` | `:4` | `:94-113` (create) | guard also skips "no ticket"; dialog `:115-130` |
| `plan.md` | `:4` | `:66-78` (switch) | |
| `implement.md` | `:4` | `:46-58` (switch) | |
| `review.md` | `:5` | `:117-129` (switch) | |
| `commit.md` | `:3` | `:60-71` (check) | |
| `work.md` | `:5` | `:74-99` | |
| `quickfix.md` | `:5` | `:135-161` | |

The git work lives only in `plugins/tce/scripts/branch.sh`.

**Remote and base today.**

- Only `## Branch convention` records them: "**Base branch:** `<branch>` on
  remote `<remote>` (or "no remote")" (template `:89`). They are recorded only
  for **Branch per ticket**; Current branch has neither.
- Nothing in any profile section mentions pull requests, merging or pushing.
- "Never push" appears in command and README text (`README.md:283`,
  `quickfix.md:288`) and in this repo's own `## Conventions`.

**Dogfooded profile** `.claude/tce/profile.md`:

- marker `1.2.0`;
- sections Tech stack, Commands, Code map, Conventions, Commit convention,
  Branch convention (Current branch, "This repo always works on `main`"),
  Preferred research sources;
- no `## Dev environment`.

### 7. Command authoring patterns `/tce:intent` can follow

- **Frontmatter**:

  | Command | `allowed-tools` | Flag |
  |---|---|---|
  | `ticket` | none | unflagged |
  | `research` | `ticket.sh`, `branch.sh` | unflagged |
  | `list` | `stage.sh` | unflagged |
  | `discuss`, `design_explore` | none | flagged |

  - Field order is `description`, `argument-hint`, then flag and/or
    `allowed-tools`.
  - Scripts are granted only by exact quoted prefix:
    `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/X.sh":*)`.
- **Reference templates.** Two exist, `references/research-document-template.md`
  and `plan-document-template.md`. Each has the same shape:
  - an HTML header comment stating who reads it and when, that it is a command
    contract, which fields downstream consumers depend on, and a contents
    list;
  - a fenced skeleton;
  - conditional sections marked in the heading, e.g. "(only for defect
    tickets)".

  The point-of-use instruction is verbatim, e.g. `research.md:303`: "Read
  `${CLAUDE_PLUGIN_ROOT}/references/research-document-template.md` now — in
  full, even if you read it earlier in this session — and structure the
  document exactly as its first template specifies".
- **Ticket reference or free input.**
  - `research.md:174-191` treats a parameter as a ticket reference or a
    question.
  - `review.md:63-107` has the most explicit classifier: "Does it START with
    a ticket reference per `tickets.md`?", with worked examples and "General
    descriptive text … is NOT a ticket number".
  - `quickfix.md:72-74` and `discuss.md:37-46` take free input only.
- **Updating an existing document instead of creating one.**
  - `research.md:334-341`: follow-ups append to the same document and set
    `last_updated` and `last_updated_note`.
  - `plan.md:118-120`: detection through the discovery script glob.
  - `plan.md:266-274`: `grep -rl` for `DECISION.md` files.
  - `init.md:519-524`: "do not clobber … show what differs … ask".
- **Docs commits.**
  - Single-step commands say "use the `/tce:commit` command"
    (`research.md:329-332`, `plan.md:452-455`). `ticket.md:242-245` commits
    inline.
  - `commit.md:27-29` skips tests, typecheck and lint for `.md`-only commits.
  - `init`, `refresh`, `discuss` and `design_explore` do not commit.
- **README listings.**
  - `plugins/tce/README.md` has a "See it work" walkthrough (`:40-56`) and
    four `## Commands` tables: Core workflow `:201-208`, Shortcuts
    `:210-215`, Helpers `:217-225`, Maintenance `:227-232`.
  - Root `README.md:21-23` describes tce as "**ticket → research → plan →
    implement**".
- **TP-0017 classification** (CLAUDE.md "Invocation control"):
  - Delegation targets, never flagged: `ticket`, `research`, `plan`,
    `implement`, `commit`.
  - User-only, flagged: `init`, `refresh`, `work`, `quickfix`, `review`,
    `discuss`, `design_explore`.
  - Read-only, unflagged: `list`.
  - `implement_eco` is flagged but appears in none of the lists.

### 8. Platform facts relevant to `/tce:intent` (web research)

- **Commands and skills.** Plugin `commands/*.md` take the same frontmatter as
  skills except `name`/`paths`. The docs call `commands/` the older format and
  recommend `skills/` for new plugins.
  - `allowed-tools` is a turn-scoped pre-approval, not a restriction.
  - `disable-model-invocation: true` blocks Claude from invoking the skill and
    removes its description from context.
- **Skill-tool invocation.** It runs inline: "the rendered `SKILL.md` content
  enters the conversation as a single message and stays there". Re-invoking
  with identical content adds a note instead of a second copy. No official
  page documents one command handing off to another. A hand-off is the model
  calling the Skill tool, with the target's body appended to the same turn.
- **Compaction.** After compaction, the most recent invocation of each skill
  is re-attached, keeping its first 5,000 tokens, within a 25,000-token
  shared budget filled newest first. This matters for a moved dialogue that
  sits deep in a long command.
- **AskUserQuestion.**
  - It is available inline in the main session and removed from every
    subagent, including `context: fork` skills.
  - The optional `askUserQuestionTimeout` setting auto-closes unanswered
    questions, after which "Claude proceeds on its own judgment".
- **Reader-profile phrasing** (Anthropic prompting docs and plain-language
  guides):
  - Describe *who the reader is and why it matters*. Anthropic: "Claude is
    smart enough to generalize from the explanation".
  - State the behaviour positively: define a term briefly on first use, and
    use familiar terms without explanation.
  - Treat length as a separate control: "cover the substance, but do not pad".
  - The built-in Explanatory/Learning output styles "produce longer responses
    than Default by design" — the length inflation a depth instruction can
    cause.
  - Output styles do not reach non-fork subagents, so a reader profile meant
    for agent output must be in the agent's prompt.
  - Plain-language sources: define jargon on first use; "not advocating
    leaving out necessary technical terms".

## Code References

- `plugins/tce/commands/ticket.md:56-66` — modes
- `plugins/tce/commands/ticket.md:96-118` — size assessment
- `plugins/tce/commands/ticket.md:120-151` — compressed track
- `plugins/tce/commands/ticket.md:153-225` — full track
- `plugins/tce/commands/ticket.md:227-266` — create and hand off to research
- `plugins/tce/commands/ticket.md:275-321` — body skeleton
- `plugins/tce/commands/ticket.md:345-360` — autonomous mode
- `plugins/tce/scripts/ticket.sh:33` — substring `find` over `thoughts/`
- `plugins/tce/scripts/stage.sh:12-27` — record contract
- `plugins/tce/scripts/stage.sh:61-62` — searched directories
- `plugins/tce/scripts/stage.sh:77-100` — `find_doc`, delimited match
- `plugins/tce/scripts/stage.sh:252-253` — lookups
- `plugins/tce/scripts/stage.sh:284-288` — record output
- `plugins/tce/commands/list.md:4` — `stage.sh` grant
- `plugins/tce/commands/list.md:98-104` — record restatement
- `plugins/tce/commands/list.md:120-147` — columns and cells
- `plugins/tce/commands/list.md:149-178` — width constraints
- `plugins/tce/commands/list.md:200-214` — example table
- `plugins/tce/templates/tce/tickets.md:85-111` — canonical sufficiency test
- `plugins/tce/commands/research.md:151-170` — operational sufficiency check
- `plugins/tce/commands/work.md:102` — compressed sufficiency check
- `plugins/tce/commands/research.md:93`, `plan.md:65`, `implement.md:77-81`,
  `review.md:136-143`, `work.md:73,219,251`, `quickfix.md:134` — ordered
  re-read sites
- `plugins/tce/commands/implement.md:335-347`, `work.md:284`,
  `commit.md:53-58` — status transitions
- `plugins/tce/commands/design_explore.md:348` — suggestion to update a
  ticket
- `plugins/tce/templates/tce/profile.md:53-97` — Commit and Branch convention
  sections
- `plugins/tce/commands/init.md:146-155` — Phase 1 branch gather
- `plugins/tce/commands/init.md:268-335` — Phase 2 dialogs
- `plugins/tce/commands/init.md:343-346` — refine list
- `plugins/tce/commands/init.md:379-400` — fill
- `plugins/tce/commands/init.md:451-461` — `thoughts/` scaffold
- `plugins/tce/commands/init.md:519-564` — Idempotency
- `plugins/tce/commands/refresh.md:27-36`, `:90-93`, `:108-111`, `:136-137`,
  `:144-150` — hand-authored sites and version marker
- `plugins/tce/README.md:45-47` — walkthrough step
- `plugins/tce/README.md:156-169` — init description and tree
- `plugins/tce/README.md:201-232` — command tables
- `plugins/tce/README.md:274-284` — branch convention bullet
- `README.md:21-23` — root catalog row for tce
- `plugins/tce/.claude-plugin/plugin.json:3`,
  `.claude-plugin/marketplace.json:15` — version `1.2.0`

## Architecture Documentation

- **Agreed profile sections share one lifecycle.**
  - Template: intro paragraph plus a bracketed options block.
  - `/tce:init`: Phase 1 sniff (a suggestion only), Phase 2 verbatim dialog,
    Phase 3 refine, Phase 4 fill (keep the intro, replace the bracket with the
    chosen bullet), Idempotency bullet with a safe default.
  - `/tce:refresh`: lists the section as hand-authored in four places.
  - Readers: guard "absent or default → skip, print nothing".
  - Release: a version bump, without which the Idempotency entry never fires.
  - CLAUDE.md: a same-commit RULE naming the span.
- **Discovery is split by strictness, on purpose.**
  - `ticket.sh`: loose, recursive, substring. Workflow commands use it to
    read everything for a ticket.
  - `stage.sh`: strict, delimited, a fixed directory list, one document per
    kind. `/tce:list` uses it.
  - CLAUDE.md forbids merging the two matchers.
- **Ownership.** The ticket system owns the envelope (tmt). tce declares the
  payload expectations in `tickets.md` and authors content only through
  `/tce:ticket`. Plugins coordinate only through project config files
  (TP-0007).
- **Reference files are read at the point of use** and survive compaction
  because they are re-read from disk. Editing one is editing the command
  contract.
- **Duplicated copy has two kinds of governance.**
  - Byte-identical: the AskUserQuestion block, twelve copies. A new dialog
    site in `intent.md` is a thirteenth.
  - Semantic mirror: the sufficiency test, three copies.

## Impact Analysis

### Existing Usages Found

- `stage.sh` record → `plugins/tce/commands/list.md:92-147`, its only
  consumer today. TP-0045b plans to re-derive the orchestrator's position from
  `stage.sh` (TP-0045b ticket, the TP-0045 epic, AC 3).
- `ticket.sh` output → `research.md:131-149`, `plan.md:79-92`,
  `implement.md:59-81`, `review.md:131-143`, `work.md:100-101`. Each reads
  "all discovered documents"; an intent file would be among them without
  change.
- `/tce:ticket` → `quickfix.md:100-123` (autonomous delegation and commit of
  the ticket file); hand-off text `ticket.md:58-59`, `:260-266`; README
  `:45-47`, `:205`; `init.md:514`.
- Sufficiency test → `templates/tce/tickets.md:85-111`, `research.md:151-170`,
  `work.md:102`.
- `profile.md` template → `init.md` (cp + fill), `refresh.md`, and every
  command reading `## Branch convention` / `## Commit convention`.

### Current Contract

- **`stage.sh`**:
  - Input: ticket IDs.
  - Output: a five-line record per ID, the labels padded to align values at
    column 11, paths relative to root, empty when absent; blank line between
    records; exit 0 except for missing `thoughts/` or missing arguments.
  - Assumption in `list.md`: exactly these five labels, in this order.
- **`ticket.sh`**: input is one ID; output is absolute paths, sorted, one per
  line.
- **`/tce:ticket --autonomous`**:
  - Input: a description.
  - Output: the canonical ID and path; it writes the file but does not commit.
  - Assumption in quickfix: creation is allowed (quickfix checks this
    itself).
- **Profile sections**: readers treat an absent section as the default.

### Adaptation Requirements

- An `intent:` field in `stage.sh`'s record changes the header (`:12-27`),
  adds a directory constant (`:61-62`) and a lookup (`:252-253`), and changes
  the output block (`:284-288`). Per the TP-0033 rule it must change together
  with `list.md:98-104`, the column list `:120-124`, the cell rule near
  `:135`, the epic rule `:142-145` and the example `:200-214`.
- An "Intent" column widens a table that already has seven visible columns in
  this repo (eight with Priority); the collapse threshold is documented at
  `list.md:170-178`.
- Changing `/tce:ticket`'s hand-off touches `ticket.md:58-59`, `:260-266` and
  README `:45-47`. The autonomous contract used by quickfix (`:345-360`) is
  out of 45a's scope (TP-0045c moves quickfix onto intents).
- New profile sections touch: the template; `init.md` (gather, Phase 2
  dialog, refine list, fill-list sentence and fill paragraph, Idempotency
  bullet); `refresh.md`'s four hand-authored sites; README (init description,
  tree comment, parameterization bullet); the dogfooded
  `.claude/tce/profile.md`; and a version bump in `plugin.json` and
  `marketplace.json`, plus the tag.
- A new `thoughts/shared/intents/` directory touches the `init.md:451-461`
  scaffold, README `:169`, and the `init.md:46` overview.
- A thirteenth AskUserQuestion copy requires the count and file list in
  CLAUDE.md to change.

### Backward Compatibility Options

- **`stage.sh`**:
  - **Append a sixth line** (`intent:`). Pros: the existing five lines are
    byte-identical in content and order. Cons: `list.md` must still learn the
    new label in the same commit.
  - **Insert it before `research:`**, in chain order. Pros: reads naturally.
    Cons: shifts line positions for any consumer reading by position;
    `list.md` reads by label, per its prose.
- **Profile sections**:
  - Absent ≡ default, as with Branch convention. This is what keeps
    un-upgraded projects byte-identical. The ticket requires it.

## Historical Context (from thoughts/)

- `thoughts/shared/discussions/2026-06-15-tce-ticket-authoring-vs-tmt-envelope.md`
  and `thoughts/shared/plans/2026-06-15-TP-0007-tce-ticket-authoring-tmt-envelope-split.md`
  — tmt owns the envelope and `/tce:ticket` is "the single home of ticket
  richness". The adapter maps lifecycle moments to backend actions. Autonomous
  mode exists for quickfix, which keeps its own "creation not allowed → stop"
  check.
- `thoughts/shared/plans/2026-07-05-TP-0019-scale-adaptive-ticket-ceremony.md`
  — the compressed and full tracks, the override, escalation in place, and
  the same body and quality bar on both tracks. It also notes that `work.md`
  never invokes `/tce:ticket`.
- `thoughts/shared/research/2026-09-03-TP-0031-declarable-branch-convention.md`
  and `thoughts/shared/plans/2026-09-05-TP-0031-declarable-branch-convention.md`
  — the rollout pattern for a profile section:
  - an Idempotency entry only fires on a version bump;
  - refresh never adds a section;
  - no forge or branch names in plugin text;
  - the dogfooded profile is updated in the same work.
- `thoughts/shared/plans/2026-07-10-TP-0022-sufficiency-criteria-sync-rule.md`
  — the three-copy semantic-mirror rule, and that the copies are deliberately
  not de-duplicated into one shared file.
- `thoughts/shared/plans/2026-09-09-TP-0033-tce-list-workflow-stage.md` — the
  stage.sh matcher, record contract, corpus verification, table width and
  glyph constraints, and that `ticket.sh` was deliberately left untouched.
- `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md`
  (untracked):
  - naming: "intent" is the artifact, "brief" the presentation, "spec" was
    rejected;
  - example reader wording at `:153-161`;
  - Delivery: with one GitHub identity "the human merges on GitHub", and the
    simplest rule is merge before the next ticket.
- `thoughts/shared/tickets/TP-0045b-step-agents-orchestrating-work.md` — what
  45b needs from 45a:
  - `/tce:work` refuses without an intent and names `/tce:intent`;
  - briefs are phrased per `## Reader`;
  - `## Delivery` tells whether a pull request is opened and who merges;
  - the plan gains a `## Decisions` section shaped like the intent's
    decisions;
  - the single-step commands stay untouched through 45b.
- `thoughts/shared/tickets/TP-0045c-single-step-commands-on-agents.md`:
  - quickfix will author a minimal *ticketless* intent autonomously;
  - how ticketless work names its research and plan documents and its branch
    is left to 45c;
  - 45c plans to consolidate the AskUserQuestion copies.

## Related Research

- `thoughts/shared/research/2026-09-03-TP-0031-declarable-branch-convention.md`
- `thoughts/shared/research/2026-09-09-TP-0033-tce-list-workflow-stage.md`
- `thoughts/shared/research/2026-07-05-TP-0019-scale-adaptive-ticket-ceremony.md`
- `thoughts/shared/research/2026-06-15-TP-0007-tce-ticket-authoring-tmt-envelope-split.md`
- `thoughts/shared/research/2026-07-10-TP-0022-sufficiency-criteria-sync-rule.md`

## Open Questions

These are points the code does not decide; they are inputs for planning.

1. **Intent template shape and how much of `ticket.md` moves.** The ticket
   body sections (`ticket.md:275-321`) overlap the intent's required content:
   scope, outcome, anchors, decisions with the rejected alternative, open
   questions, ticket pointer. They are not identical:
   - the ticket has no "anchors" or "rejected alternative" field;
   - the intent has no user stories or Implementation Plan placeholder.
   - Whether `/tce:ticket` keeps its own discussion (for human-readable
     tickets) or shrinks to envelope-plus-summary is open; the discussion's
     follow-up list says "reduced to human-readable ticket creation".
2. **Ticketless addressing.** No existing command takes a `thoughts/` path as
   the identity of ticketless work. Neither matcher sees slug-named files.
   45c owns ticketless research and plan naming.
3. **`stage.sh` record placement**: an appended sixth line versus insertion
   in chain order. The `list.md` column choice also has to fit the table-width
   constraint.
4. **Where clarification answers land.** Today `research.md:169` points to an
   undefined "context" section. With an intent, the answers have a defined
   home.
5. **Delivery fields.** The branch section already records base branch and
   remote, but only under Branch per ticket. Under Current branch neither is
   recorded, while Delivery's "is a pull request opened" may still apply.
6. **Session habit vs. command instruction.** The "no body writes" criterion
   is already true of every command. What remains is the habit (commit
   `1da6644`), which only command or CLAUDE.md text can steer.
7. **CLAUDE.md nits found in passing.** The sufficiency section's "Phase 1
   step 4" now sits at step 5. `implement_eco` is not named in the TP-0017
   classification lists.
