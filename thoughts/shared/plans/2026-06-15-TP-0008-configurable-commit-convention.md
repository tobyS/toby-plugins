---
date: 2026-06-15
ticket: TP-0008
topic: Make commit convention configurable via /tce:init
research: thoughts/shared/research/2026-06-15-TP-0008-configurable-commit-convention.md
git_commit: 6d48c44
status: ready
---

# Plan: Configurable commit convention via /tce:init (TP-0008)

## Overview

Stop hardcoding Conventional Commits in the tce plugin. `/tce:init` agrees a commit
convention with the user (from three standard options, default pre-selected by
sniffing git history), stores it in a dedicated `## Commit convention` section of
`.claude/tce/profile.md`, and `/tce:commit` (plus every command that writes a commit)
reads and follows it. `/tce:refresh` re-detects and reconciles the convention like
other factual sections. Existing projects pick it up through init's idempotency
upgrade list.

## Decisions (from the question checkpoint)

1. **Storage:** a dedicated, structured `## Commit convention` section in profile.md
   (not folded into `## Conventions`).
2. **Refresh:** **full reconciliation** — refresh re-detects the convention from git
   history and offers to reconcile it. *This overrides the ticket's original "refresh
   out of scope" line*; the convention is therefore a **factual / refreshable**
   profile section, and init's and refresh's Phase 1 detection must stay in lock-step
   (CLAUDE.md "refresh tracks init" rule).
3. **`#<ticket-number>` ID placement:** use the canonical ticket ID from tickets.md
   after `#` (so `#123` on GitHub, `#TP-0008` on tmt); documented as intended for
   numeric issue trackers. No bare-number extraction.

## Conventions shipped

Three selectable conventions. The canonical ticket ID always comes from
`.claude/tce/tickets.md`; placement differs per convention:

- **Conventional Commits** (default): `<type>(<ticket-id>): <description>`; types
  `feat, fix, refactor, docs, test, chore, style, perf, ci, build`; first line < 72;
  what-not-how, why for non-obvious. (Exactly today's behavior.)
- **Plain / freeform:** `<ticket-id>: <description>`; imperative subject, optional
  body; first line < 72.
- **Issue-reference `#<ticket-number>`:** `#<ticket-id>: <description>`; for numeric
  issue trackers; first line < 72.

In all three, the ticket-ID portion is omitted when a commit isn't about a ticket.

## Current state

- `commit.md:59-75` is the **only** definition of the format ("Use conventional
  commits", `<keyword>(<ticket-id>): <description>`, keyword list, <72). It already
  reads `profile.md` for test/typecheck/lint (`commit.md:15-19`).
- Four files inline literal Conventional strings: `quickfix.md:119,147,169,211-215`,
  `ticket.md:179`, `implement.md:117`. All other commit references defer to
  `/tce:commit`.
- `templates/tce/profile.md` has no commit section; "commit discipline" is only an
  example inside the free-form `## Conventions` (template line 41).
- `init.md` Phase 1 sniffs git only for ticket-system detection; no commit-convention
  detection. Version is **3.1.0** in `plugins/tce/.claude-plugin/plugin.json` and the
  marketplace entry.
- `refresh.md` re-derives only factual sections and explicitly preserves
  `## Conventions` (refresh.md:78-79, 90-93).

## Desired end state

- `profile.md` carries a `## Commit convention` section; `commit.md` reads it and
  formats accordingly, defaulting to Conventional when the section is absent.
- `/tce:init` detects, proposes (verbatim dialog), and writes the chosen convention;
  re-running init on a pre-3.2.0 project offers to add the section.
- `/tce:refresh` re-detects and reconciles the convention.
- No command hardcodes the Conventional shape except as the documented default.
- tce plugin at **3.2.0** (plugin.json + marketplace.json).

---

## Phase 1 — Core read path: profile template + commit.md  ✅ DONE

**Goal:** the runtime mechanism, so a hand-edited profile already drives commits.

1. `plugins/tce/templates/tce/profile.md`: add a `## Commit convention` section
   (placed after `## Conventions`, before `## Preferred research sources`) with a
   placeholder explaining init fills it and listing the three options. Keep the
   existing `## Conventions` "commit discipline" example wording intact (it covers
   *other* commit discipline, not the message format).
2. `plugins/tce/commands/commit.md:59-75`: rewrite `## Commit Message Format` to:
   "Read the `## Commit convention` section of
   `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` and format the message exactly as it
   specifies (the ticket-ID placement comes from there; resolve the canonical ID per
   `.claude/tce/tickets.md`). **If the section is absent** (older config), default to
   Conventional Commits:" then keep today's spec verbatim as the fallback. Preserve
   the docs-only/code distinction (`commit.md:25-27`) and the Important footer.

**Success criteria**
- Automated: `claude plugin validate ./plugins/tce` passes.
- Manual: commit.md no longer asserts Conventional unconditionally; the fallback spec
  matches today's text; template section reads cleanly.

## Phase 2 — /tce:init: detect, propose, write, upgrade, version bump  ✅ DONE

**Goal:** init agrees and persists the convention; existing projects can upgrade.

1. **Phase 1 detection** (init.md ~71-138): add a gather item "Commit convention" —
   sniff the last ~30 subjects (`git log --format=%s`): majority `^\w+(\(.+\))?: ` →
   Conventional; majority `^#?\d+[: ]` → `#<ticket-number>`; else Plain; empty/mixed →
   Conventional. Used only to pre-select the dialog default.
2. **Phase 2 dialog** (init.md ~184-253): add a new **verbatim** dialog site (contract
   copy) after the policy dialogs. Intro (1-2 sentences) + question "Which commit
   convention should tce use when it writes commits?" — header "Commits", options
   recommended-first (detected one first with " (Recommended)" + detection reasoning):
   Conventional Commits / Plain or freeform / Issue-reference (#<ticket-number>).
   Follow the existing AskUserQuestion guidelines block (unchanged — no 9-copy edit).
3. **Phase 4 fill** (init.md ~282-298): add a step that writes the chosen convention's
   full spec block into `## Commit convention`. Carry the three canonical spec blocks
   verbatim in init.md (they are the source the section is filled from; the
   Conventional block must match commit.md's fallback — note this as a sync point).
4. **Idempotency** (init.md ~415-427): add a `**v3.2.0**` bullet — "profile.md gained a
   `## Commit convention` section; if missing, walk the user through choosing a
   convention (same dialog) and add it." Re-stamp the marker as usual.
5. **Version bump:** `plugins/tce/.claude-plugin/plugin.json` and the tce entry in
   `.claude-plugin/marketplace.json` 3.1.0 → **3.2.0**. (Marker stamping already reads
   plugin.json, so no further change.)

**Success criteria**
- Automated: `claude plugin validate ./plugins/tce` and `claude plugin validate .`
  pass.
- Manual: the new dialog follows the guidelines block; the v3.2.0 upgrade bullet is
  present; the Conventional spec block in init matches commit.md's fallback; versions
  match across both manifests.

## Phase 3 — /tce:refresh: full reconciliation  ✅ DONE

**Goal:** refresh re-detects and offers to reconcile the convention (per the override).

1. **Phase 1** (refresh.md ~53-79): add commit-convention re-detection using the same
   heuristic as init Phase 2 step 1; add it to the factual gather list.
2. **Phase 2 classification** (refresh.md ~86-93): add `## Commit convention` to the
   **factual / refresh-target** set (so it's reconciled, proposed per-section for user
   approval), and ensure the "do not re-derive Conventions" exclusion (refresh.md:78-79)
   still applies only to the free-form `## Conventions` block, not the new section.
3. Keep the version-marker handling as-is (already maintained the same way as init).

**Success criteria**
- Automated: `claude plugin validate ./plugins/tce` passes.
- Manual: refresh's Phase 1 detection wording mirrors init's; the new section is named
  as a refresh target; no contradiction with the preserved `## Conventions` block.

## Phase 4 — Neutralize inlined literals, composite sync, docs  ✅ DONE

**Goal:** remove the remaining hardcoded Conventional strings; update docs.

1. **Inlined literals → convention-dependent:**
   - `quickfix.md:119,147,169` and the summary block `211-215`: replace literal
     `docs(...)`/`feat/fix(...)` strings with "a docs-only commit message formatted
     per the project's commit convention (see profile.md), describing <X>", keeping a
     Conventional example only as illustration.
   - `ticket.md:179`: same treatment for the ticket-creation docs commit.
   - `implement.md:117`: make the status-file example convention-neutral (or note
     "per the project's commit convention").
2. **Composite-command sync (CLAUDE.md rule):** re-read `work.md` and `quickfix.md`
   after the commit.md change. work.md only defers (research confirmed) — verify no
   format text needs updating. quickfix.md is handled in step 1.
3. **README** (`plugins/tce/README.md`): note at lines ~90-94 / ~98 / ~142 / ~177-180
   that `/tce:init` agrees a commit convention stored in profile.md and `/tce:commit`
   follows it.

**Success criteria**
- Automated: `claude plugin validate ./plugins/tce` passes.
- Manual: `grep -rn "conventional" plugins/tce` shows only the default/fallback and
  docs, no unconditional assertions; no stray hardcoded `docs(`/`feat(` literals that
  imply Conventional is mandatory; README mentions the setting.

## Phase 5 — Ticket update + dogfood this repo + final validation

**Goal:** reconcile the ticket with the scope change, dogfood, validate everything.

1. **Update TP-0008 ticket:** remove the "refresh out of scope" line from Out of
   Scope; add a Notes & Updates entry (2026-06-15) recording the three checkpoint
   decisions and the refresh scope expansion; add the now-in-scope refresh AC.
2. **Dogfood:** add a `## Commit convention` section (Conventional Commits) to this
   repo's own `.claude/tce/profile.md` and bump its marker to 3.2.0 — exercising the
   new section end-to-end on the marketplace repo itself.
3. **Final validation:** `claude plugin validate .`, `./plugins/tce`, `./plugins/tmt`;
   confirm the AskUserQuestion guidelines block is byte-identical across all 9 files
   (we added a dialog *site* but did not edit the block); re-grep for residual
   hardcoded conventions.

**Success criteria**
- Automated: all three `claude plugin validate` invocations pass.
- Manual: ticket reflects the real scope; this repo's profile carries the new section
  at marker 3.2.0; 9-copy block unchanged.

## Testing strategy

This is a markdown/JSON repo with no runtime. Verification = `claude plugin validate`
(manifests stay well-formed) + careful manual read-through of the prompt edits +
targeted greps for residual hardcoded Conventional literals. No script changes, so no
throwaway-project smoke test is needed.

## Out of scope (unchanged)

- Gitmoji and conventions beyond the three listed.
- A hook that validates/enforces hand-written commit messages.
- Per-keyword customization within Conventional Commits.
- `claude plugin tag` / pushing the release — the human decides when to release.

## Notes / risks

- **Spec duplication:** the Conventional spec exists both as commit.md's fallback and
  as init's fillable block. They must agree; called out in Phase 2 step 3. Acceptable
  (a small, documented sync point) vs. the complexity of a single shared source the
  commands can't reference at runtime.
- **Dialog copy is contract-governed** (TP-0001): the new init dialog ships frozen;
  word it carefully.
