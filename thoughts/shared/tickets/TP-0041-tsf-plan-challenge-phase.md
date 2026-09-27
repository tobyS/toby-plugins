# TP-0041: tsf — challenge a plan before the human is asked to approve it

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-09-27
**Updated:** 2026-09-27

## Problem Statement

The plan travels from the planning agent straight to the human's approval gate,
with nothing in between checking it against itself. Every resulting defect is
visible *in the plan*, but only surfaces much later and expensively:

- Acceptance criteria no agent can verify surface at the plan-compliance gate as
  "cannot verify from diff" verdicts, burning bounded fix rounds.
- A plan that contradicts the project's stack surfaces as a failing verification
  in the middle of implementation, after a batch was built against it.
- A plan that misses part of the ticket surfaces at the spec-coverage gate — or,
  worse, in the human's review.

The human's plan approval is deliberately a one-minute judgment of intent and
trade-offs (§6.5: "let the human approve intent and trade-offs in under a
minute"). It is not, and should not become, a technical audit of the plan.

## Desired Outcome

After the plan is written and before the human is asked to approve it, a
fresh-context agent that did not write the plan challenges it against stated
criteria and returns an evidenced verdict. The plan step acts on the findings
(revising, bounded) so what reaches the human has survived the challenge;
findings only the human can settle are surfaced in the plan summary rather than
dropped. No plan reaches implementation carrying a defect the challenge names.

The criteria, as a closed list:

- **a) Meaningful criteria** — each acceptance/verification criterion asserts the
  ticket's outcome, not a tautology or a restatement of the code.
- **b) Agent-verifiable criteria** — each criterion can be verified by an agent
  from the inputs the gates actually receive, or is explicitly flagged manual.
- **c) No stack contradiction** — the plan does not contradict the project's
  stack, its conventions, or the research's evidence.
- **d) Full spec coverage** — nothing the ticket asks for is unaddressed by some
  increment.
- **e) Genuinely independent increments** — as §6.5 requires: no walkthrough step
  in disguise, no increment whose verification is another increment.

## User Stories / Use Cases

- As the factory's human, I want the plan I am asked to approve to have already
  been challenged, so that my minute goes to intent and trade-offs rather than
  auditing criteria.
- As the factory's operator, I want unverifiable criteria caught at plan time, so
  that the verification pipeline does not burn bounded fix rounds discovering
  them.
- As the factory's operator, I want a plan that contradicts the stack caught
  before implementation spends a batch building against it.

## Acceptance Criteria

- [ ] A challenge runs in every plan cycle before the plan gate; no plan reaches
      `tsf:needs-plan-approval` (or `tsf:implement`) without a challenge verdict
      for the plan *as it stands*.
- [ ] The challenging agent runs in a fresh context and never receives the
      planning agent's reasoning or transcript (§7/§11.2's starvation contract).
- [ ] The criteria are enumerated in the plugin, covering at least a–e above,
      each stating what counts as a finding.
- [ ] Each finding is evidenced against a named increment or criterion in
      `plan.md`; the verdict is pass or fail on stated grounds.
- [ ] A failing challenge sends the plan back for revision, bounded by a
      constant; exhaustion parks `tsf:needs-human` with the findings linked — the
      plan is never forced through.
- [ ] Findings the agent cannot settle (a trade-off, a product question) reach
      the human in the plan summary.
- [ ] The challenge output is persisted where the human can open it (linked from
      the plan summary) and where a later cycle can tell whether it still applies
      to the current plan.
- [ ] The challenge does not re-run when nothing about the plan changed, and its
      token and latency cost per plan cycle is stated.
- [ ] DESIGN.md, `plugins/tsf/README.md` and every contract touched are updated
      in the same commit.

## Out of Scope

- Extending or configuring the four post-implement verification gates — that is
  TP-0042 and §7's "future work".
- Project-custom or configurable challenge criteria.
- Challenging the spec or the research; this challenges the plan only.
- Removing or weakening the human's plan approval.

## Open Questions

- [ ] Should the human ever see a plan that failed the challenge and be able to
      overrule it? Draft assumption: **no** — the plan is revised first and the
      human sees the finished plan.

## Questions for Research/Planning

- [ ] A read-only gate agent (`tools: Read, Grep, Glob`, returning report content
      the dispatcher writes) like §7's four, or a step-dispatched critic like
      tle's `loop-goal-critic`?
- [ ] One cycle or two? A plan → challenge → revise loop inside one cycle versus
      a dispatcher-driven round, given the foreground-dispatch requirement.
- [ ] Does it need a label, or does it live entirely inside the plan step (no new
      state, no new `Next step` value)?
- [ ] What are its inputs? Criterion (c) appears to need the research and the
      project's stack — does that widen a starved payload past what §11.2
      permits?
- [ ] Can it reuse `report.md`'s `head:` / `verdict:` machine lines? There is no
      pull request and no logic head at plan time.
- [ ] Which constant bounds the revision rounds, and where is the counter read
      from (report filenames, as the gate rounds are)?

## References

- DESIGN.md §6.5 (the plan format and summary), §7 (the starvation contract; the
  note that extending the gate family is future work), §11.2 (per-agent inputs)
- `plugins/tle/agents/loop-goal-critic.md` — precedent for a define-time critic
  that guards an artifact before it is committed to
- TP-0040 (plan-gate re-approval), TP-0042 (meaningful tests at verification)

## Implementation Plan

## Notes & Updates

### 2026-09-27

Created from the user's feedback. The criteria a–d are the user's; (e) was added
because §6.5's independently-verifiable-increment rule is exactly the kind of
plan property nothing currently checks. Deliberately kept to the plan: the spec
and the research already have their own human gate and their own downstream
catcher.
