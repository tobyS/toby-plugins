# TP-0045d: Settle and Close the Orchestrator Improvements Collector — Implementation Plan

## Overview

TP-0045d collected small observations from real orchestrator runs. This batch
gives each of the intent's twelve routing rows (A to L) a final outcome: it warns
when a project's profile is older than the plugin, tightens three spots of the
loop's text, fixes what the "for you to check" count means, files the moved items
as sub-tickets of the epic, releases tce 1.7.0, and takes the ticket to Done.

## Current State Analysis

- **A (progress):** a foreground agent blocks the orchestrator and has no channel
  but its final message (research, Item A). The human reported in the planning
  round that the terminal's own agent panel is enough.
- **B (older profile):** `plugins/tce/scripts/work.sh:46-68` checks two
  environment variables only; no shipped script reads `plugin.json` or a version.
  `plugins/tce/references/work-loop.md:97-110` prints nothing on success.
- **C (pull-request body):** in GH-37 the orchestrator edited a scratchpad copy
  of the dossier before posting, following that project's `tickets.md`, not tce's
  Step 10, which posts the dossier as-is (`work-loop.md:275-280`).
- **D (count):** `plugins/tce/agents/verifier.md:119-121` does not say what a
  bullet is, `verifier.md:140-141` and `plugins/tce/references/dossier-template.md:104`
  name different sources, and real runs counted criteria once and bullets once.
- **E, F, G:** covered in text (`work-loop.md:186-188`, `plugins/tce/references/work-dispatch.md:96-97`,
  `work-loop.md:203`), but real runs follow them on 1 of 5, 4 of 6 and 0 of 7. The
  intent routed them "tick, no change"; the human moved them to Build while planning.
- **H, I, J, K, L:** open or dropped as the intent's table says; research holds
  the anchors.

## Desired End State

- A step command run against an older profile prints a bold, multi-line warning
  naming both versions and `/tce:init`, and continues. A current, newer, unmarked
  or placeholder profile prints nothing. The refusal block stays byte-identical.
- `work-loop.md` Step 6 names the artifact check where the runs skipped it, says
  which header `answers:` carries, and makes the `Understood:`/`Approach:` intro a
  required part of the message that asks.
- The verifier's return and the dossier count the same thing: bullets.
- TP-0045h, i, j and k exist; `CLAUDE.md`'s pin pointer names TP-0045k.
- This plan's `## Item outcomes` records all twelve rows; tce is 1.7.0 in both
  manifests with the tag command handed over; TP-0045d is Done after the human's
  checks.

### Key Discoveries:

- `work.sh` runs under `set -e` (`work.sh:30`), so a failed `read` or `grep` needs
  a guard; bash's `[[ =~ ]]` needs neither `grep` nor `jq`.
- The manifest is at `$SCRIPT_DIR/../.claude-plugin/plugin.json` in the repo and in
  the plugin cache (research, Item B).
- `work-loop.md:97` is `preflight`'s only reader and reads by label, so an added
  labelled line breaks nothing.
- `/tce:quickfix` reaches Step 0 twice (`plugins/tce/commands/quickfix.md:36-37`, `:66`).
- The Closeout's lines are fixed and written by the orchestrator at Step 11, after
  the last phase (`work-loop.md:297-306`), so implementers cannot fill it.

## What We're NOT Doing

- Building anything for item A: no hook, status line, mod, or agent change.
- The work of H, I, J and K; enforcing item L.
- Rewriting the posted pull-request body or adding `gh pr edit` (the leftover gap
  goes into TP-0045j).
- The question form and communication style (TP-0047), and approval output (TP-0048).
- Changing the planner, its layout, or any return field or status.
- Changing the epic's text or its done check; re-running `/tce:init` on this repo,
  whose profile will show the new warning until the human does.
- Adding text to the ticket beyond ticking its existing boxes and the done transition.

## Implementation Approach

Five small phases in dependency order: script and warning first, then the loop's
text, the count, the stubs, and finally the outcomes and release, which need the
earlier commits. Each spec below gives the exact wording.

## Decisions

- **Routing as in the intent's table: H, I, J and K move to their own tickets** — over folding them into this batch: each changes a step's working or an agent's contract. *(yours)*
- **Item L is dropped** — over filing a ticket: no real run has asked for it, and the profile states it as the human's rule. *(yours)*
- **An older profile warns boldly over several lines and the run continues** — over refusing or a one-line note: a refusal would stop every project on each plugin bump, and one line is easy to miss. *(yours)*
- **This batch closes the collector; later observations get their own tickets** — over keeping TP-0045d open: an open collector would hold the epic open indefinitely. *(yours)*
- **The run ticks the ticket's checklist itself, as a one-off exception** — over the human ticking it: the human chose this; it covers checklist items only. *(yours)*
- **Item A: the terminal's own agent panel is enough, so nothing is built and that observation is the recorded outcome** — over a hook, a status line, or a ticket of its own: the human saw it suffice. *(yours)*
- **Items E, F and G are built now, in the loop's text** — over ticking them with no change, with or without a follow-up ticket: the human chose to act on the observed behaviour. *(yours)*
- **Item C is closed with the recorded reason; the "posted body shows items as open after confirmation" gap goes into TP-0045j** — over changing Steps 10 and 12 here: tce's own delivery already posts as-is. *(yours)*
- **"For you to check" counts list bullets, one bullet per action naming the criteria it covers; rewording `verifier.md` counts as removing an ambiguity, not as a contract change** — over one bullet per criterion or template wording only: the count then matches what the human sees and what they do. *(yours)*
- **The moved items become sub-tickets TP-0045h, i, j and k** — over main tickets TP-0049 to TP-0052: the human wants them under the epic. *(yours)*
- **Outcomes are recorded in the plan and copied into the dossier** — over adding rows to the ticket: the checklist exception stays as narrow as it was set. *(yours)*
- **`preflight` gains one labelled `profile:` line** — over a separate `work.sh` mode: no second call at Step 0, and the reader already reads by label. *(decided for you)*
- **Versions are compared part by part with `[ -lt ]`** — over `sort -V`: no new tool and it follows the numeric precedent at `work.sh:54`. *(decided for you)*
- **Anything that cannot be compared stays silent (no marker, `FILLED-BY-INIT`, unreadable file, or a marker newer than the plugin)** — over warning on those: the intent requires silence for no marker, and `/tce:init` has no path for a newer one. *(decided for you)*
- **A failed environment check prints only its refusal block, without the warning** — over printing both: TP-0045e measured that block as byte-identical and it must stay so. *(decided for you)*
- **`answers:` carries the header the dialog showed** — over the planner's original header: it is what the human answered, and the planner still has the order to match on. *(decided for you)*
- **The artifact check is named at both `challenge-fix` and `revise` in Step 6** — over `challenge-fix` only: both resume the planner inside the same loop. *(decided for you)*
- **Outcomes live in a new `## Item outcomes` section of this plan rather than inside `## Implementation Closeout`** — over the Closeout: its lines are fixed and written after the last phase, so no phase can fill it. *(decided for you)*
- **The new sub-tickets do not hold the epic open: its done check stays a to d, and each stub says so** — over the epic waiting for them: the intent closes this collector so the epic is not held up, and no session edits the epic's body. *(decided for you)*
- **Ticket boxes are ticked with no commit text added, including item A's** — over appending hashes as the ticket's own criterion words it: the exception covers ticks only, and `## Item outcomes` carries the commits. *(decided for you)*
- **tce goes to 1.7.0** — over 1.6.1: a new warning is new visible behaviour. *(decided for you)*
- **Item A leaves no text in the plugin** — over a README note about the panel: the intent asks for the reason on record, which `## Item outcomes` is. *(decided for you)*

## Phase 1: Warn when the profile is older than the plugin (item B)

### Overview

`preflight` reports the comparison as a labelled line; Step 0 prints the warning.

### Changes Required:

#### 1. Script

**File**: `plugins/tce/scripts/work.sh`
**Changes**: Add the `profile_state` function above `preflight()`, call it from
`preflight`, and print `profile:` between `timeout:` and `detail:`. In the header:
line 3 becomes "the orchestrating step commands make", line 9 says "A step command
needs each agent's result", "Prints exactly three lines" for `preflight` becomes
"four", and add `#   profile:    ok | older <profile version> <plugin version>`.
State in the header that anything not comparable reports `ok`, and that
`artifact`'s three lines are unchanged.

```bash
# Is the project's profile older than this plugin? Prints "ok" or
# "older <profile version> <plugin version>". Anything that cannot be compared
# (no marker, the template's placeholder, a missing file) is "ok".
profile_state() {
    local profile manifest line i pv vv
    local -a p v
    local version='([0-9]+)\.([0-9]+)\.([0-9]+)'
    local marker_re="^<!-- tce-config-version: ${version} -->[[:space:]]*$"
    local manifest_re="\"version\"[[:space:]]*:[[:space:]]*\"${version}\""
    profile="$(tce_project_root)/.claude/tce/profile.md"
    manifest="$SCRIPT_DIR/../.claude-plugin/plugin.json"
    if [ ! -r "$profile" ] || [ ! -r "$manifest" ]; then
        echo ok
        return 0
    fi
    line=""
    IFS= read -r line < "$profile" || true
    if ! [[ "$line" =~ $marker_re ]]; then
        echo ok
        return 0
    fi
    p=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}")
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ $manifest_re ]]; then
            v=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}")
            break
        fi
    done < "$manifest"
    if [ "${#v[@]}" -ne 3 ]; then
        echo ok
        return 0
    fi
    pv="${p[0]}.${p[1]}.${p[2]}"
    vv="${v[0]}.${v[1]}.${v[2]}"
    for i in 0 1 2; do
        if [ "${p[$i]}" -lt "${v[$i]}" ]; then
            printf 'older %s %s\n' "$pv" "$vv"
            return 0
        fi
        if [ "${p[$i]}" -gt "${v[$i]}" ]; then
            break
        fi
    done
    echo ok
}
```

In `preflight`: add `profile` to the `local` line, assign `profile="$(profile_state)"`,
and add `printf 'profile:    %s\n' "$profile"` after the `timeout:` line.

#### 2. Step 0

**File**: `plugins/tce/references/work-loop.md`
**Changes**: Leave the existing paragraph and refusal block byte-identical. After
the block, add:

````markdown
Otherwise, if `profile:` says `older <profile version> <plugin version>`, print
the lines between the fences below as a normal message, **exactly as written**
with only the two versions filled in — the fence lines are not part of it — and
carry on with the run in the same turn. Print it once per run: `/tce:quickfix`
reaches this step twice. Any other `profile:` value prints nothing.

```
**This project's tce config is older than the plugin.**

**Profile: <profile version>. Plugin: <plugin version>.**

**Run `/tce:init` to bring it up to date. This run continues.**
```
````

#### 3. Docs

**File**: `plugins/tce/README.md`
**Changes**: After the paragraph ending "stopped rather than moved to the
background." (lines 325-328 today), add: "The same check compares the
`tce-config-version` on the first line of `profile.md` with the plugin's version.
An older profile gets a bold warning to re-run `/tce:init`, and the run carries on;
a profile with no version marker stays silent."

**File**: `CLAUDE.md`
**Changes**: In the "Foreground is required" bullet (line 429 ff.), after "stopped,
not backgrounded).", add: "It also compares the profile's `tce-config-version` with
the plugin's and warns, never refuses, when the profile is older (TP-0045d)." In
"Migrations & version markers", after the marker sentence, add: "`work.sh preflight`
reads the marker's line-1 shape too, so a change to that shape also updates
`work.sh`."

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tce` pass (in repo root)
- [x] The behaviour test below prints exactly the expected lines, and every run of `work.sh preflight` exits 0:

```bash
R=/Users/toby/code/work/toby-plugins
T=$(mktemp -d); mkdir -p "$T/p/scripts" "$T/p/.claude-plugin" "$T/proj/.claude/tce"
cp "$R/plugins/tce/scripts/work.sh" "$R/plugins/tce/scripts/lib.sh" "$T/p/scripts/"
run() { printf '{\n  "name": "tce",\n  "version": "%s"\n}\n' "$1" > "$T/p/.claude-plugin/plugin.json"
        printf '%s\n# Project Profile\n' "$2" > "$T/proj/.claude/tce/profile.md"
        CLAUDE_PROJECT_DIR="$T/proj" "$T/p/scripts/work.sh" preflight | grep '^profile:'; }
run 1.6.0  '<!-- tce-config-version: 1.3.0 -->'     # profile:    older 1.3.0 1.6.0
run 1.6.0  '<!-- tce-config-version: 1.6.0 -->'     # profile:    ok
run 1.6.0  '<!-- tce-config-version: 1.7.0 -->'     # profile:    ok
run 1.10.0 '<!-- tce-config-version: 1.9.0 -->'     # profile:    older 1.9.0 1.10.0
run 2.0.0  '<!-- tce-config-version: 1.10.0 -->'    # profile:    older 1.10.0 2.0.0
run 1.6.0  '<!-- tce-config-version: FILLED-BY-INIT -->'   # profile:    ok
run 1.6.0  '# Project Profile'                      # profile:    ok
rm "$T/proj/.claude/tce/profile.md"
CLAUDE_PROJECT_DIR="$T/proj" "$T/p/scripts/work.sh" preflight | grep '^profile:'   # profile:    ok
```

- [x] `plugins/tce/scripts/work.sh preflight` with both variables set prints four labelled lines, with `foreground:` and `timeout:` unchanged in meaning
- [x] `git diff` of `work-loop.md` in this phase shows only added lines in Step 0 (the refusal block is untouched)

#### Manual Verification:

- [ ] In a scratch project (see "Manual Testing Steps" 1), `/tce:implement <intent>` at marker 1.3.0 shows the three bold lines naming 1.3.0 and the plugin's version, then its "No plan for demo-greeting" line; with the marker at the plugin's version the same command shows no warning

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `c3ebb07a8b4da718355b4f6929d5d78776b68323`
- **Commit**: `128caf8` feat(TP-0045d): warn when the profile is older than the plugin
- **Did**: `work.sh` gains `profile_state` and a `profile:` preflight line; Step 0 prints the warning; README and CLAUDE.md updated. No test files (repo has none); scratch script run.
- **Issues**: none
- **Verification**: ✅ behaviour test (8 cases, all exit 0), ✅ four labelled lines, ✅ work-loop diff additions only, ✅ validate marketplace and all four plugins
- **Fix rounds**: 0/3

---

## Phase 2: Tighten the loop's text at Step 6 (items E, F, G)

### Overview

Say at the point of action what the runs skipped. Only the orchestrator's text
changes; `planner.md` and its layout do not.

### Changes Required:

#### 1. Step 6

**File**: `plugins/tce/references/work-loop.md`
**Changes**:

- **Point 2 (G, F).** Replace "If it returns questions, print its `Understood:` and
  `Approach:` lines as the intro, then ask every question through AskUserQuestion —
  one decision per question, its options exactly as returned (recommended first), at
  most four per call." with: "If it returns questions, the message that asks starts
  with its `Understood:` and `Approach:` lines, word for word, as the intro; never
  invoke AskUserQuestion without them. Then ask every question through
  AskUserQuestion — one decision per question, its options exactly as returned
  (recommended first), at most four per call. A header over 12 characters is
  shortened for the dialog."
- **Point 2 (F).** Replace "resume the planner with `mode: write` and the answers
  verbatim" with "resume the planner with `mode: write` and the answers verbatim,
  each under the header the dialog showed".
- **Point 3 (E).** Replace "resume the planner with `mode: challenge-fix` and the
  failing lines, then challenge again" with "resume the planner with
  `mode: challenge-fix` and the failing lines, run Step 4's artifact check on the
  plan it names, then challenge again".
- **Point 4 (E).** In both places that resume with `mode: revise`, add "run Step 4's
  artifact check on the plan it names," before "re-run the challenger".

#### 2. Payload

**File**: `plugins/tce/references/work-dispatch.md`
**Changes**: In `planner, mode: write` (lines 95-97), replace "each question's header
and the human's answer, verbatim, one per line" with "each question's header as the
dialog showed it and the human's answer, verbatim, one per line".

#### 3. Question layout

**File**: `plugins/tce/references/work-brief.md`
**Changes**: In the bullet at lines 57-60, replace "with an intro above the dialog
that carries the `Understood:` / `Approach:` lines" with "with an intro above the
dialog that carries the `Understood:` / `Approach:` lines word for word, and never
without them; a header over 12 characters is shortened for the dialog, and `answers:`
carries the shortened one". `planner.md` keeps its layout, so the brief/question span
needs no change there.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] `grep -c "artifact check on the plan it names" plugins/tce/references/work-loop.md` prints 3 (one in point 3, two in point 4; `grep -c` counts lines, so a hard-wrapped match is checked by reading)
- [x] `grep -n "header the dialog showed" plugins/tce/references/work-loop.md` and `grep -n "as the" plugins/tce/references/work-dispatch.md` show the new wording, and `grep -n "never invoke AskUserQuestion without them" plugins/tce/references/work-loop.md` matches (reading across a line wrap where needed)
- [x] The `### AskUserQuestion dialog guidelines` block in `work-loop.md` is byte-identical to `plugins/tce/commands/intent.md`'s copy (extract both and `diff`)
- [x] `git diff` shows no change to `plugins/tce/agents/planner.md`

#### Manual Verification:

- [ ] In a scratch project (see "Manual Testing Steps" 2), `/tce:plan <intent>` shows the `Understood:` and `Approach:` lines in the terminal above the question dialog

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `bd91144` fix(TP-0045d): name the intro, header and artifact check at Step 6
- **Did**: `work-loop.md` Step 6 points 2-4 name the intro, the shortened header and the artifact check; `work-dispatch.md` and `work-brief.md` match. No test files (repo has none).
- **Issues**: none
- **Verification**: ✅ validate marketplace and all four plugins, ✅ grep count 3, ✅ new wording found, ✅ guidelines block diff empty, ✅ `planner.md` unchanged
- **Fix rounds**: 0/3

---

## Phase 3: Make the check count mean bullets (item D)

### Overview

Remove the ambiguity about what a "for you to check" item is, in both files that
count it. No field, status or return shape changes.

### Changes Required:

#### 1. Verifier

**File**: `plugins/tce/agents/verifier.md`
**Changes**:

- In verify step 6's skeleton, change the bullet to
  `- <criterion numbers>. <what to do> — run \`<exact command>\` (or: <exact steps>); pass looks like <observable result>. <Why it needs a human.>`.
- After '"For you to check:" reads `None.` when nothing remains.', add: "One bullet
  per thing the human has to do; a bullet may cover several criteria and names each by
  number. `For you to check: n` in your return counts these bullets. `Criteria met a/b`
  counts criteria, and `a` leaves out every criterion a bullet names."
- In `mode: dossier` point 2, replace "items for you to check from `## Verification`"
  with "the bullets under \"For you to check:\" in `## Verification`".

#### 2. Dossier template

**File**: `plugins/tce/references/dossier-template.md`
**Changes**:

- Line 104 becomes: "**For you to check `c`** — the bullets under \"For you to
  check:\" in the plan's `## Verification`. `## For you to check` copies them one to
  one, so its list has `c` items too."
- In the "Criteria met" bullet (lines 94-96), after "verified as met (by the checker
  or by the verifier's own attempt)", add "; a criterion a \"For you to check\" bullet
  names is not met yet".

`work-loop.md`'s Step 11 prints the counted-facts line and does not depend on what
the count means, so the dossier span needs no text change there.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] `grep -n "One bullet" plugins/tce/agents/verifier.md` and `grep -n "the bullets under" plugins/tce/agents/verifier.md plugins/tce/references/dossier-template.md` find the new wording in both files
- [x] `git diff` of `verifier.md` shows no change to the `tce-return` examples, the status values or the `## Return` field list

#### Manual Verification:

None.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `5e3dfd3` fix(TP-0045d): make the check count mean bullets
- **Did**: `verifier.md` defines a "for you to check" bullet and the return's count; `dossier-template.md` counts the same bullets and treats a named criterion as not met yet. No test files (repo has none).
- **Issues**: none
- **Verification**: ✅ validate marketplace and all four plugins, ✅ new wording found in both files, ✅ diff leaves `## Return` and the status values untouched
- **Fix rounds**: 0/3

---

## Phase 4: File the moved items and repoint the pins (items H, I, J, K)

### Overview

One stub per moved group, under the epic, with `CLAUDE.md` naming the pins' ticket.

### Changes Required:

#### 1. Stub tickets

**Files**: `thoughts/shared/tickets/TP-0045h-design-exploration-in-intent.md`,
`thoughts/shared/tickets/TP-0045i-concerns-survive-session-break.md`,
`thoughts/shared/tickets/TP-0045j-what-delivery-leaves-behind.md`,
`thoughts/shared/tickets/TP-0045k-step-agent-model-pins.md`
**Changes**: Follow the layout in `.claude/tce/tickets.md` and an existing sub-ticket
(`TP-0045g`): `# TP-0045x: <title>`, `**Status:** Open`, `**Estimated Complexity:**
Medium`, `**Created:**`/`**Updated:**` with today's date. Then the line "Sub-ticket of
TP-0045 (the epic), moved out of TP-0045d. Not part of the epic's done check, which
names a to d." and `## Problem Statement`, `## Desired Outcome`, `## Out of Scope` and
`## References`. Each `## References` links
`thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md` with the
finding number, and `thoughts/shared/research/2026-10-30-TP-0045d-orchestrator-improvements.md`.

- **TP-0045h** (finding 1): move the design-exploration check into `/tce:intent`, which
  records the outcome; the planner follows it and asks only for older intents; plus
  the two `/tce:design_explore` defects (mockup folder name without the ticket ID,
  uncommitted `DECISION.md`). Anchors: `plugins/tce/agents/planner.md:99-107`,
  `plugins/tce/references/work-loop.md:165-167`, `:206-208`.
- **TP-0045i** (finding 6): concerns live only in the orchestrator until the dossier;
  make them durable in each agent's artifact. Changes every agent's contract. Anchors:
  `work-loop.md:191`, `work-dispatch.md:166-167`, `verifier.md:147-148`.
- **TP-0045j** (findings 4, 5, and finding 7's body item): who owns delivery when the
  backend's "complete" transition delivers too, what the merge reference is then,
  dossier permalinks after a squash merge, and a posted body that still shows items as
  open after Step 12's confirmation. Include the GH-37 evidence (research, Item C,
  including the 2026-10-29 `PATCH` on pull request 132). Anchors: `work-loop.md:272-284`,
  `work-loop.md:329-334`, `dossier-template.md:108-111`.
- **TP-0045k** (Cost section): model pins for the step agents, using the TP-0029
  policy, each pin proven on a real dispatch. Anchors: `CLAUDE.md`'s "All five agents"
  bullet, `thoughts/shared/tickets/TP-0029-tle-agent-model-pins.md`.

#### 2. Pin pointer

**File**: `CLAUDE.md`
**Changes**: In the "All five agents are `model: inherit`" bullet, replace
"(TP-0045d)" with "(TP-0045k)".

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` passes
- [ ] `ls thoughts/shared/tickets/TP-0045[hijk]-*.md` lists exactly four files, and `plugins/tmt/scripts/valid-statuses.sh` accepts their `Open` status (the tmt hook raises nothing on write)
- [ ] Each of the four contains `2026-10-15-tce-work-first-run-findings.md` (`grep -L` over them prints nothing)
- [ ] `grep -n "TP-0045k" CLAUDE.md` matches the pins bullet and `grep -n "TP-0045d" CLAUDE.md` matches only the preflight sentence from Phase 1
- [ ] `git diff --stat` shows no change to `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md`

#### Manual Verification:

None.

---

## Phase 5: Record the outcomes and release (all rows)

### Overview

Fill in the outcomes, tick the ticket's boxes, bump tce and prepare the tag hand-over.

### Changes Required:

#### 1. Outcomes

**File**: `thoughts/shared/plans/2026-10-30-TP-0045d-orchestrator-improvements.md`
**Changes**: In `## Item outcomes` below, replace each `<Phase N commit>` with the
short hash from that phase's implementation log.

#### 2. Ticket boxes

**File**: `thoughts/shared/tickets/TP-0045d-orchestrator-improvements.md`
**Changes**: Change `- [ ]` to `- [x]` on the one `## Collected items` line and the
three `## Acceptance Criteria` lines. Nothing else: no appended text, and no status
change (the orchestrator makes the done transition at Step 11 or 12, so the tagged
criterion is confirmed before Done).

#### 3. Version bump

**Files**: `plugins/tce/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
**Changes**: `1.6.0` → `1.7.0` in both. No Idempotency entry in `init.md`: this version
changes nothing a project's config must contain.

#### 4. Tag hand-over

Record in the phase log the exact command, on this phase's bump commit `<sha>`:
`git tag -s tce--v1.7.0 <sha> -m "tce 1.7.0"`. Later plan and closeout commits mean
`claude plugin tag` (HEAD only) will not fit. The agent never creates the tag.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tce` pass
- [ ] `claude plugin tag --dry-run ./plugins/tce` passes
- [ ] `grep -c "1.7.0" plugins/tce/.claude-plugin/plugin.json` prints 1, and the tce entry in `.claude-plugin/marketplace.json` says 1.7.0
- [ ] `sed -n '/^## Item outcomes/,/^## Testing Strategy/p' thoughts/shared/plans/2026-10-30-TP-0045d-orchestrator-improvements.md | grep -c '<Phase'` prints 0: no placeholder is left in `## Item outcomes`
- [ ] `git diff` of the TP-0045d ticket shows exactly four changed lines, each only `[ ]` → `[x]`

#### Manual Verification:

- [ ] Pull request 123's edit history is read, outside the sandbox (`gh` is denied inside it), read-only: `gh api graphql -f query='{repository(owner:"tobyS",name:"chat-sustainability"){pullRequest(number:123){lastEditedAt editor{login} userContentEdits(first:10){nodes{editedAt editor{login}}}}}}'`. Empty `lastEditedAt` and `userContentEdits` confirm nobody edited it after creation; anything else is a web-UI edit, still outside tce, so row C's reason stands with that added
- [ ] The human creates the tag with the command from the phase log, and `git tag --list 'tce--v*'` lists `tce--v1.7.0` (`git tag -v tce--v1.7.0` for the signature)

---

## Item outcomes

Dossier mode copies this list after the narrative in `## What was built`.

- **A, progress lines:** nothing built. The terminal's own agent panel shows enough
  during a foreground dispatch, by the human's observation in this plan's question
  round (2026-10-30). Agent-sent lines are not possible: an agent's only channel is
  its final message, and the orchestrator is blocked meanwhile.
- **B, older profile:** shipped in `<Phase 1 commit>`.
- **C, pull-request body:** closed with a reason. In GH-37 the orchestrator edited a
  copy before posting, following that project's `tickets.md` transition; tce's Step 10
  posts the dossier as-is. The remaining gap moved to TP-0045j.
- **D, check count:** shipped in `<Phase 3 commit>`.
- **E, artifact check after `challenge-fix`:** shipped in `<Phase 2 commit>` (intent's
  "tick" changed to Build by the human).
- **F, answer headers:** shipped in `<Phase 2 commit>` (same).
- **G, intro before the questions:** shipped in `<Phase 2 commit>` (same).
- **H, design exploration in the intent:** moved to TP-0045h.
- **I, concerns across a session break:** moved to TP-0045i.
- **J, delivery and permalinks:** moved to TP-0045j.
- **K, model pins:** moved to TP-0045k.
- **L, enforcing "next ticket after merge":** dropped; no real run has asked for it,
  and the profile states it as the human's rule.

---

## Testing Strategy

### Unit Tests:

None as committed files: the repo has none under `plugins/tce/`. Phase 1's scratch
script covers `profile_state`, including `1.9.0` against `1.10.0`, the placeholder, no
marker and a missing file. `claude plugin validate` runs in every phase, as the
profile's Test command.

### Integration Tests:

The manual scratch runs below, which go through a real step command.

### Manual Testing Steps:

1. **Warning.** Create the scratch project, then start Claude Code in it with the
   plugin from source:

   ```bash
   R=/Users/toby/code/work/toby-plugins
   S=$(mktemp -d); cd "$S"; git init -q
   mkdir -p .claude/tce thoughts/shared/intents thoughts/shared/research
   cp "$R/plugins/tce/templates/tce/tickets.md" .claude/tce/tickets.md
   sed '1s/.*/<!-- tce-config-version: 1.3.0 -->/' "$R/plugins/tce/templates/tce/profile.md" > .claude/tce/profile.md
   printf -- '---\nticket: none\nstatus: agreed\n---\n\n# Intent: demo greeting\n\nPrint a greeting from hello.sh.\n' > thoughts/shared/intents/2026-10-30-demo-greeting.md
   git add -A; git commit -qm scratch
   export CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 BASH_DEFAULT_TIMEOUT_MS=600000
   claude --plugin-dir "$R/plugins/tce"
   ```

   Run `/tce:implement thoughts/shared/intents/2026-10-30-demo-greeting.md`. Pass: the
   three bold warning lines, then "No plan for demo-greeting — run `/tce:plan <argument>`
   first.", the lane's line for a project with no research, so the run went on past
   Step 0. Set line 1's marker to the plugin's version, commit and run it
   again. Pass: the same result without the warning. (This can only be checked in a
   real session because the printed text is the model's, not the script's.)

2. **Intro.** In the same project add a research document that leaves a question open,
   commit it, and run `/tce:plan`:

   ```bash
   printf -- '---\ndate: 2026-10-30\ngit_commit: %s\nstatus: complete\nlast_updated: 2026-10-30\n---\n\n# Research: demo greeting\n\nNo code exists yet.\n\n## Open Questions\n\n1. Should the greeting go to stdout or stderr?\n' "$(git rev-parse HEAD)" > thoughts/shared/research/2026-10-30-demo-greeting.md
   git add -A; git commit -qm research
   ```

   Run `/tce:plan thoughts/shared/intents/2026-10-30-demo-greeting.md`. Pass: the
   `Understood:` and `Approach:` lines are visible above the dialog. Quit at the dialog;
   the project is throwaway. E and F change only what the orchestrator is told, so their
   effect shows on the next real runs, not in this check.

## Performance Considerations

`preflight` reads two small files once per run. No effect on a run's token use beyond a
few added lines in `work-loop.md`.

## Migration Notes

Projects with an older marker see the warning from 1.7.0 on until they re-run `/tce:init`,
which stamps the current version. Projects with no marker see no change. This repository's
own profile (1.3.0) is one of them, as the intent notes.

## References

- Original ticket: `thoughts/shared/tickets/TP-0045d-orchestrator-improvements.md`
- Intent: `thoughts/shared/intents/2026-10-30-TP-0045d-orchestrator-improvements.md`
- Related research: `thoughts/shared/research/2026-10-30-TP-0045d-orchestrator-improvements.md`
- Findings: `thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md`
- Similar implementation: `plugins/tce/scripts/work.sh:54` (numeric floor), `plugins/tce/references/work-loop.md:98-110` (verbatim block)
