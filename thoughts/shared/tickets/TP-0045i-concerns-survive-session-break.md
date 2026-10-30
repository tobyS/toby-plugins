# TP-0045i: concerns survive a session break

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-10-30
**Updated:** 2026-10-30

Sub-ticket of TP-0045 (the epic), moved out of TP-0045d. Not part of the epic's
done check, which names a to d.

## Problem Statement

Concerns live only in the orchestrator's conversation until the dossier
dispatch. A run that resumes in a new session has lost them: in GH-37 the
researcher's "4 web sources blocked by the sandbox" never reached the dossier
after the resume.

## Desired Outcome

Every agent writes each concern into its own artifact as well: the research
document, the phase log's `**Issues**` line, `## Verification`, the plan's
`## Decisions` or risk notes. The verifier's dossier mode collects them from
disk. The return's `concerns:` stays as the in-run signal but is no longer the
only copy.

This changes every agent's contract, which is why it left TP-0045d.

## Out of Scope

- What counts as a concern, and the status vocabulary.
- How concerns are shown to the human during a run.

## References

- `thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md` —
  finding 6
- `thoughts/shared/research/2026-10-30-TP-0045d-orchestrator-improvements.md` —
  "Items H to L"
- `plugins/tce/references/work-loop.md:205` — concerns kept for the dossier
- `plugins/tce/references/work-dispatch.md:167-168` — the same, for the payload
- `plugins/tce/agents/verifier.md:151-152` — the dossier's `## Concerns`, which
  already takes the phase logs' unresolved `**Issues**` lines
