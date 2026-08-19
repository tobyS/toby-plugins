---
description: Define a machine-checkable loop goal through guided discussion, and write it to thoughts/shared/loops/<goal-slug>/goal.md with a ready-to-paste /goal condition.
argument-hint: "[goal description]"
disable-model-invocation: true
---

# Define Loop Goal

You are tasked with turning a rough intention ("build this small web app until it works") into a **machine-checkable goal file**: a granular checklist where every item states an observable outcome and a concrete way to prove it, plus the ops facts and budgets the loop's agents need every iteration.

## Project context

This command ships in the **tle** (Toby Loop Engineering) plugin and is stack-agnostic. It hardcodes no framework, no package manager, no test runner, and no directory layout — every such fact comes from the project or from the user.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` **if it exists** — it is optional enrichment only, a shortcut to the project's boot/test/lint commands and conventions so you can *propose* ops facts instead of asking cold. tle works fine without tce installed: if the file is absent, do not mention it and do not suggest `/tce:init` — ask the user for the commands instead.
- `<goal-slug>` is a placeholder for the kebab-case slug agreed in this session (e.g. `todo-app-mvp`), never a literal.
- `item-NN` is a placeholder for a stable checklist item ID (`item-01`, `item-02`, …), never a literal.

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

---

## Workflow Context

**This is Step 1 of 3 in the tle loop workflow:**

| Step | Action | Purpose |
|------|--------|---------|
| **→ 1** | **`/tle:define`** | **Agree a granular, machine-checkable goal; write `goal.md`** |
| 2 | paste `/goal <condition>` | Pin the condition so Claude Code keeps taking turns until it is met |
| 3 | `/tle:run <goal-file>` | Run one iteration: verify → spec → implement → log; `/goal` decides whether another turn starts |

**Your role in this step:** Be the demanding editor of the goal. The loop that follows is only as good as the checklist you produce here — a vague item is an item the loop can neither reach nor prove, and a subjectively-judged item is one it can talk itself into passing.

**Input:** A rough goal description from the user (plus the project's own state)
**Output:** `thoughts/shared/loops/<goal-slug>/goal.md` and a `/goal` condition string for the user to paste

---

## CRITICAL: WHAT MAKES THIS FILE WORTH WRITING

- The checklist is the loop's **oracle**. Every item must be provable without your judgement being in the loop.
- Prefer a **command with a meaningful exit code** over anything a model has to assess. Browser scenarios are the fallback, not the default.
- Goal files are **immutable once a loop starts**. This command never edits or overwrites an existing goal file — a changed goal means a new slug and a new loop.
- Item IDs are **permanent handles**. The verifier keys its verdict vector on them and `/tle:run`'s stall check compares those vectors; renaming or reusing an ID silently corrupts stall detection.

## Initial Setup

When this command is invoked:

1. **Check if a parameter was provided**:

   - If a goal description was provided as a parameter, skip the default
     message and begin immediately: treat it as the starting statement of the
     goal and go to "Step 1: Converge on the goal" below.

2. **If no parameter was provided**, respond with:

```
I'm ready to define a loop goal. Tell me what you want built — a sentence or two is enough; we'll sharpen it together into a checklist the loop can actually verify.

Tip: You can also invoke this command with the goal directly: `/tle:define a todo app that persists across reloads`
```

Then wait for the user's goal description.

## Steps to follow once you have the goal description

### Step 1: Converge on the goal

Restate the goal in one sentence and confirm it with the user. Establish the **boundary** explicitly: what is in the goal, and what is deliberately not (the loop will otherwise wander into it).

Then agree the **slug** — kebab-case, short, derived from the goal (e.g. `todo-app-mvp`). Propose one and let the user correct it.

**Immutability guard — do this before any further work:** check whether `thoughts/shared/loops/<goal-slug>/` already exists.

- **If it exists**: STOP. Tell the user that goal files are immutable once a loop starts, show the existing path, and ask for a different slug. Never edit, overwrite, extend, or "refresh" an existing goal file, and never write into an existing loop directory — even if the user asks you to. If they want a changed goal, that is a new slug and a new loop.
- **If it does not exist**: continue.

### Step 2: Survey what already exists

Read the project just enough to ground the checklist in reality — is this a bare directory, a scaffolded app, a half-built one? Look at the repo root, the package/build manifest if there is one, and any existing tests.

If `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` exists, read it now for the boot/test commands and conventions; treat what it says as a proposal to confirm, not as truth. If it does not exist, skip it silently.

Do not research deeply — this is a grounding pass, not `/tce:research`. You need enough to propose sensible ops facts and to know which checklist items are already true on day one.

### Step 3: Decompose into granular checklist items

Break the goal into items where **one item = one observable outcome = one check**. Aim for items a competent implementer could land in a single small increment; the loop makes exactly one step of progress per iteration, so coarse items mean many iterations with nothing observably changing.

For each item, write:

- **Done when** — the outcome in user-visible terms ("adding an item and reloading the page still shows it"), never in implementation terms ("`useLocalStorage` hook exists").
- **Verify by** — how it is proven (Step 4).

Present the draft checklist to the user and iterate until they are satisfied. Explicitly ask whether anything they consider part of "done" is missing — a goal with a hole in it is a loop that stops early.

### Step 4: Push every item down the oracle hierarchy

For each item, in order of preference:

1. **A command that exits 0 when the item is done and non-zero otherwise** — a test, a build, a typecheck. This is always the target. If the command does not exist yet, that is fine and often better: state it anyway, and the loop will write the test and make it pass.
2. **A user-level browser scenario** — only for what end-to-end interaction alone can prove. Write it as a narrative a user would recognise ("open `/`, add an item, reload the page, the item is still listed"). **Never** name a selector, DOM id, CSS class, or component: the UI drifts across iterations and the goal file must not.

Tell the user plainly which items ended up as browser scenarios and why a command could not carry them — that is where the loop's verification is weakest, and where an absent `chrome-devtools-mcp` will produce `cannot-verify`.

### Step 5: Collect the ops facts

The facts every agent needs each iteration, so none of them rediscovers (or guesses) them:

- **Boot the app** — the command that starts it, plus the port/URL if relevant.
- **Run tests** — the command the implementer must see green before committing.
- **Base commit** — the current `HEAD`. Run `git rev-parse HEAD` and record the full sha; the verifier diffs test files from it.
- **Test file locations** — the paths or globs the verifier diff-reviews for weakened, skipped, or deleted tests.
- **Other** — anything else an agent would otherwise have to work out: env setup, seed data, a dev-server quirk.

Propose values from Step 2's survey (and the tce profile if present) and confirm them; ask for the ones you cannot determine.

### Step 6: Agree the budgets

At minimum **max iterations** — the number that appears in the `/goal` condition's "or stop after N iterations" clause and that `/tle:run` checks each iteration. Propose a number scaled to the checklist (a rough starting point: two to three iterations per checklist item), and say what happens when it is hit: the loop stops and reports, it does not silently continue.

Add any further budget the user wants (a wall-clock stop, a spend ceiling) as an extra bullet, noting that only max iterations is enforced by the runner — the rest is enforced by the `/goal` evaluator reading the transcript, which is soft.

### Step 7: Assign stable IDs

Number the agreed items `item-01`, `item-02`, … in checklist order, zero-padded to two digits. Say once, to the user, that these IDs are permanent for the life of the loop.

### Step 8: Write the goal file

**Read `${CLAUDE_PLUGIN_ROOT}/references/goal-file-template.md` now — in full, even if you read it earlier in this session** — and write `thoughts/shared/loops/<goal-slug>/goal.md` following the skeleton and the authoring guidance it carries.

Fill in every bracketed placeholder from what was agreed in Steps 1–7. **Never write the goal file with a placeholder left in it** — a `[command]` that reaches an agent is a fabricated ops fact waiting to happen.

The `## /goal condition` section is not decoration: it carries the loop's restart directive, which is what makes the next turn re-invoke `/tle:run` even if compaction has dropped the runner's skill body. Render it with the agreed slug, the goal file path, and the max-iterations number substituted in.

### Step 9: Hand off

Present, in this order:

1. The path to the written goal file.
2. The `/goal` condition string in a fenced block, ready to copy — with a note that `/goal` is a built-in and cannot be invoked on the user's behalf, which is why this paste is manual.
3. The exact next two steps:
   - paste the `/goal` condition into Claude Code;
   - then run `/tle:run thoughts/shared/loops/<goal-slug>/goal.md`.

Then stop. Do not start the loop, do not run `/tle:run`, and do not offer to.

## Important Rules

- **Never edit an existing goal file**, and never write into an existing `thoughts/shared/loops/<goal-slug>/` directory. This command only ever creates a new one.
- **Never write a placeholder into the goal file.** Every bracketed slot is filled from an agreed value.
- **Never invent an ops fact.** If you cannot determine the boot or test command, ask.
- **Never accept a subjectively-judged item** ("the UI looks good", "performance is acceptable") into the checklist. Push for an observable outcome, or agree with the user to leave it out of the loop and verify it by hand afterwards.
- **All user interaction happens here.** The loop's agents can never ask the user anything — every question the loop would want answered must be settled in this command.
