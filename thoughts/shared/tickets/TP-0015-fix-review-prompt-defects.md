# TP-0015: Fix the concrete command-prompt defects from the 2026-07 review

**Status:** Open
**Estimated Complexity:** Small
**Created:** 2026-07-03
**Updated:** 2026-07-03

## Problem Statement

An independent review of the tce plugin (`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`, Section 1
"Concrete defects") identified seven concrete defects in the command prompts:
instructions the model cannot execute (referencing mechanisms that don't exist in
tce), contradictory or wrong in-prompt examples, numbering errors, and dead
machinery inherited from the claude-template/HumanLayer lineage. Each wastes
context tokens; some cause user-visible misbehavior (`/tce:research <ID>` can
greet-and-wait instead of starting), and unexecutable instructions train the
model to treat the prompts' instructions as optional.

## Desired Outcome

All seven defects are fixed: every instruction in the tce commands and agents is
executable in a tce-configured project, examples and numbering are consistent,
and assumptions are replaced by checks. Composites stay in lock-step per the
CLAUDE.md composite rule.

## User Stories / Use Cases

- As a tce user, I want `/tce:research TP-0042` to start researching immediately
  so that I don't have to repeat the ticket reference in a second message.
- As a tce user implementing an older plan, I want `/tce:implement` to notice the
  repo has moved on since research so that stale research claims get spot-checked
  instead of silently trusted.
- As the plugin maintainer, I want the prompts free of dead lineage machinery so
  that every line either guides behavior or is removed.

## Acceptance Criteria

- [ ] `/tce:research` invoked with a ticket reference or question begins work
      immediately; the "I'm ready to research" greeting appears only when invoked
      without arguments (mirroring `plan.md`'s parameter check).
- [ ] No tce command instructs a "thoughts sync" (dead instruction in `plan.md`
      Step 5 — there is no sync mechanism in tce).
- [ ] `thoughts-locator.md` and `research.md` describe only directory structures
      tce/tmt actually create; the `thoughts/searchable/` path-correction rules
      and the `global/` / `[username]/` / `prs/` directory descriptions are
      removed or replaced by the real tree (research confirms nothing in tce/tmt
      still supports them).
- [ ] `plan.md` step numbering is consistent (no duplicate "5." items in Step 1,
      no "1, 2, 2, 3, 4" sequence in Step 5) and in-prose cross-references like
      "proceed directly to step 5" resolve unambiguously.
- [ ] `plan.md`'s Example Interaction Flow shows `/tce:plan`, not
      `/tce:implement`.
- [ ] `implement.md` replaces the asserted "Repository state guarantee" with an
      instruction to compare the research frontmatter `git_commit` against
      current HEAD and to spot-verify research claims about files that changed
      since — while keeping the fast path for same-session composite runs.
- [ ] `plan.md` no longer references "plan mode".
- [ ] `quickfix.md`'s `/simplify` reference is guarded ("if a simplify skill is
      available…") or replaced by a description of the intent.
- [ ] `work.md` and `quickfix.md` are updated in the same commit wherever they
      mirror changed content (CLAUDE.md composite rule).

## Out of Scope

- Shortening/restructuring the command bodies or moving templates to reference
  files (TP-0016).
- Frontmatter/machinery adoption (TP-0017).
- Changes to the "documentarian, not critic" rules (TP-0018).
- Any change to the workflow chain, document formats, or ticket structure.

## Open Questions

None — the defects were confirmed with concrete file:line evidence in the
review.

## Questions for Research/Planning

- [ ] Verify nothing in tce or tmt (init scaffolding, scripts, hooks) still
      creates or relies on `thoughts/searchable/`, `thoughts/global/`,
      `thoughts/[username]/`, or `prs/` — then decide: delete the references or
      generalize the locator's tree description to "whatever exists under
      thoughts/".
- [ ] Enumerate the exact edit sites for each defect, including every composite
      mirror (`work.md`, `quickfix.md`) affected.
- [ ] Does the state-guarantee replacement also need wording in `work.md`
      Phase 4 (same-session fast path) so the check isn't pointlessly repeated
      inside composites?

## References

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — Section 1 (file:line evidence for each
  defect).
- `plugins/tce/commands/{research,plan,implement,quickfix,work}.md`,
  `plugins/tce/agents/thoughts-locator.md` — the files carrying the defects.
- `CLAUDE.md` — "Composite commands must track the single-step commands".

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-07-03
Created from the independent plugin review (Fable 5). All seven Section-1
defects deliberately bundled into one ticket: each fix is a small surgical
markdown edit, and the review already provides the evidence a research phase
would otherwise gather.
