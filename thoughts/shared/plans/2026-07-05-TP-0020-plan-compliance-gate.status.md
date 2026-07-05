# Status: TP-0020 Plan-Compliance Gate

**Plan:** `thoughts/shared/plans/2026-07-05-TP-0020-plan-compliance-gate.md`
**Base commit:** afcbd10c77a95a2008401420b40cc85a2862196a
**Started:** 2026-07-05

## Phases

### Phase 1: Author the plan-compliance-checker agent
✅ Complete — `plugins/tce/agents/plan-compliance-checker.md` created (read-only
tools, criteria-only envelope, Inspector read scope). `claude plugin validate`
passes. Ticket set to In Progress.

### Phase 2: Wire the gate into implement.md + mirror into composites
✅ Complete — implement.md: allowed-tools extended for git reads; status-file
`**Base commit**` field + record-on-create rule; new `## Plan-Compliance Gate`
section between Final Verification and Ticket Status Transitions; done-flip gated
on the gate passing. work.md 4d re-describes the gate inline; quickfix.md Final
Summary surfaces it (mechanics inherited via the `tce:implement` delegation). All
in one commit per the composite-tracking rule. `claude plugin validate` passes.

### Phase 3: Documentation & sync rule
✅ Complete — CLAUDE.md gains a TP-0020 sync-rule section (agent + implement.md +
work.md + quickfix.md move together; agent is the one non-research/verification
agent; no TP-0017/manifest impact). README Agents table gains the
plan-compliance-checker row (lead-in reworded) and the /tce:implement bullet
mentions the gate. All manifests validate.
