# TP-0016: Shrink command prompts — reference files for templates, deduplicated instructions

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-07-03
**Updated:** 2026-07-03

## Problem Statement

The independent plugin review (`plugins/tce/fable_review.md`, Section 2,
findings 1 and 2) found the tce command prompts work against current
context-engineering guidance in two compounding ways:

1. **Length / the compaction cliff.** `plan.md` is 773 lines; `research.md`,
   `review.md`, and `init.md` are ~470 each. Official guidance keeps skill
   bodies concise (under ~500 lines, detail in reference files). An invoked
   command's text stays in context for the whole session, and after
   auto-compaction only roughly the first ~5,000 tokens per invoked skill are
   re-attached (within a combined budget) — so in exactly the sessions that
   compact (`/tce:work` invoking work + plan + implement + commit), the tails
   of the long prompts (plan.md's Success Criteria Guidelines, Common
   Patterns, Sub-task Spawning sections) silently vanish.
2. **Repetition.** The same instruction often appears 3–4 times per file
   ("read FULLY, no limit/offset", "wait for ALL sub-agents", "don't re-read
   researched files"). This is 2024-era prompt style; current guidance is to
   state each rule once and add repetition only for observed failures. The
   community post-mortem of this command set's own ancestor (QRSPI) named
   "instruction budget overflow" (~150–200 instructions per prompt) as the
   reason the monolithic commands failed at scale.

## Desired Outcome

The primary workflow commands — `plan.md` and `research.md` first, others
opportunistically — have bodies comfortably within the ~500-line guidance
(target ~400), with stable reference material (the research-document template,
the plan template, the status-file format) moved into plugin reference files
that the command reads at the moment of use. Each rule is stated once,
well-placed. Behavior and output quality are unchanged: same chain, same
document structures, same checkpoints.

This applies the plugin's own TP-0013 insight (durable content belongs in
files read at use time, not in fading context) to the commands' templates
themselves: reference files re-read from disk survive compaction the way
tickets and research docs already do.

## User Stories / Use Cases

- As a tce user running `/tce:work` on a Large ticket, I want the plan and
  status-file formats to survive auto-compaction so that late implementation
  phases still follow the same structure as early ones.
- As the plugin maintainer, I want each behavioral rule stated once so that
  editing a rule doesn't require hunting down its three restatements.
- As a tce user, I want command quality to be unchanged — this is an internal
  restructuring, not a behavior change.

## Acceptance Criteria

- [ ] `plan.md` and `research.md` bodies are ≤ ~450 lines each with no loss of
      behavior; the document templates they carry today live in plugin
      reference files loaded at use time (mechanism per research — e.g.
      `${CLAUDE_PLUGIN_ROOT}`-relative reads).
- [ ] Within each edited command, no instruction is stated more than once
      unless a documented, observed failure justifies the repetition (the
      justification is recorded in the plan or a comment).
- [ ] The composite commands and the CLAUDE.md sync rules are honored and
      updated where they mirror restructured content (including the
      "templates/ is the single source of truth" convention if template
      locations change).
- [ ] The current compaction re-attachment behavior for invoked skills is
      verified against up-to-date Claude Code documentation during research
      and recorded in the research document (the review's ~5k-token figure is
      the hypothesis, not a given).
- [ ] `claude plugin validate .` and the plugin manifest validations pass; an
      end-to-end smoke run of `/tce:research` + `/tce:plan` in a scratch
      project produces documents with the same structure as before.

## Out of Scope

- Changing workflow semantics, the chain, checkpoints, or document formats.
- The composite context-budget question (`context: fork`, fresh-session advice
  — review finding 2.3, unticketed).
- Frontmatter adoption (TP-0017).
- `init.md` / `review.md` / `design_explore.md` restructuring beyond
  opportunistic wins — they may follow in a later ticket once the pattern is
  proven on plan/research.

## Open Questions

None at ticket level — mechanism choices are research/planning questions.

## Questions for Research/Planning

- [ ] What is the sanctioned mechanism for plugin commands to load supporting
      files at runtime (plain `Read` of `${CLAUDE_PLUGIN_ROOT}/...`, skill
      directory conventions, or converting commands to skill-with-references
      layout)? Verify `${CLAUDE_PLUGIN_ROOT}` substitution applies where
      needed.
- [ ] What are the current, documented compaction limits for invoked
      skills/commands?
- [ ] Which repeated instruction blocks are load-bearing (check git history —
      some repetitions were added in response to real failures, e.g. TP-0013)
      versus pure lineage inheritance?
- [ ] Which sections of `plan.md`/`research.md` are per-invocation behavior
      (stay in the body) versus stable reference (move out)?
- [ ] How does this interact with the repo convention "small surgical edits
      are safer than rewrites" — this ticket is a deliberate, planned
      exception and the plan should stage it reviewably (e.g. one command at a
      time).

## References

- `plugins/tce/fable_review.md` — Section 2, findings 1 and 2 (with sources:
  Anthropic context-engineering post, code.claude.com skills docs, QRSPI
  writeups); uncommitted at ticket-creation time.
- `plugins/tce/commands/plan.md` (773 lines), `plugins/tce/commands/research.md`
  (470 lines) — primary targets.
- `CLAUDE.md` — composite-tracking rule, TP-0013 re-read rule (the same
  principle this ticket extends to templates).

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-07-03
Created from the independent plugin review (Fable 5). Findings 2.1 and 2.2
deliberately bundled: deduplication and body-shrinking are the same edit pass,
and doing them separately would touch the same lines twice. Estimated Large:
the mechanical work is moderate but the risk profile (prompt refactor of the
two most important commands, sync obligations, behavior must not change)
warrants full research + a staged plan.
