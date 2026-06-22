# TP-0014: Rewrite the tce README intro to be hands-on first and convincingly motivated

**Status:** Done
**Estimated Complexity:** Small
**Created:** 2026-06-22
**Updated:** 2026-06-22

## Problem Statement

Real user feedback on tce: *"the process looks complex & I cannot see where it
helps me — medium-complex tasks are handled by my Claude Code well without any
process on top of a prompt."*

The current `plugins/tce/README.md` invites exactly this reaction. It opens with a
conceptual framing ("A context-engineering development workflow…", then a *Why
context engineering?* section that explains the four-step process) **before** the
reader ever sees the workflow do anything for them. Two concrete gaps:

a. **It doesn't motivate why a shared, repo-stored context process pays off.** The
   strongest arguments for tce are never stated: increased overall reliability
   through *explicitating* context (instead of it living only in one developer's
   head or one chat session), *equalization* of output quality across a whole team,
   and a *self-learning* effect because every context document (tickets, research,
   plans) is committed to the repo and reused.

b. **It leads with process explanation, not hands-on "how to do it."** A reader
   evaluating the plugin has to digest the philosophy before getting a feel for what
   actually happens when they use it.

The net effect: a capable Claude Code user who already gets good results on medium
tasks sees overhead, not value, and bounces.

Note: TP-0011 (Done) already restructured all three READMEs to be user-first,
extracted `CONTRIBUTING.md`, regrouped the tce command tables, and added the
"Built by Toby" blurb. This ticket is a **narrower follow-up** specifically about
the *introduction* of the tce README, driven by feedback received after TP-0011
shipped. It must build on TP-0011's structure, not undo it.

## Desired Outcome

The tce README's introduction is rewritten so that a skeptical-but-capable reader
quickly grasps **where tce helps them** and **what using it actually looks like**,
before any process theory. When this is complete:

- The intro **leads with a concrete, hands-on worked example** — one real task
  narrated through the chain (ticket -> research -> plan -> implement), showing the
  artifacts each step produces and where they're stored — before any conceptual
  "why context engineering" explanation.
- The intro **names the objection head-on** ("Claude already handles medium tasks
  fine without a process") and answers where tce adds value *beyond* that case
  rather than pretending the objection doesn't exist.
- The three value propositions are **explicitly present and articulated**:
  1. **Reliability through explicitation** — context is written down, not trapped
     in one head or one session, so outcomes are more consistent.
  2. **Team-wide quality equalization** — the same context chain lifts every team
     member's output toward the same bar.
  3. **Self-learning via the repo** — context documents are committed and reused,
     so the project gets better at being worked on over time.
- The framing speaks to **both the individual developer** ("what do I get today")
  **and the team/adopter** ("why standardize this across the team"), giving each a
  clear reason to care.

## User Stories / Use Cases

- As a capable Claude Code user skeptical of added process, I want to see within
  the first screenful where tce helps beyond what I already get, so that I don't
  dismiss it as overhead.
- As a developer evaluating the plugin, I want a concrete walkthrough of a real
  task moving through the chain, so that I understand what using tce actually feels
  like before reading any theory.
- As a team lead considering adoption, I want the reliability / quality-equalization
  / self-learning arguments stated explicitly, so that I can justify standardizing
  the workflow across my team.

## Acceptance Criteria

- [ ] The tce README intro leads with a **hands-on worked example** of one real
      task flowing through ticket -> research -> plan -> implement, naming the
      artifacts produced at each step and where they live (`thoughts/`), placed
      **before** any conceptual process explanation.
- [ ] The intro **explicitly names** the "Claude handles medium tasks fine without
      a process" objection and gives a direct answer for where tce adds value.
- [ ] All three value propositions appear and are clearly articulated: reliability
      via context explicitation; output-quality equalization across a team;
      self-learning through repo-stored context documents.
- [ ] The intro addresses **both** individual-developer and team/adopter readers
      (neither framing is dropped).
- [ ] No factual usage detail present today is lost: Requirements, Install, Set up
      a project, Update, Commands, Agents, "How project parameterization works", and
      the Contributing link remain accurate and intact.
- [ ] TP-0011's outcomes are **not regressed**: the `tce — Toby Context Engineering`
      heading, the "Built by Toby" blurb placement, the grouped command tables, and
      the bottom link to `CONTRIBUTING.md` all remain.
- [ ] `claude plugin validate ./plugins/tce` still passes (READMEs aren't validated,
      but nothing structural should break).

## Out of Scope

- No changes to the marketplace root `README.md` or the tmt README — tce README
  only. (A later ticket may align them if this framing proves out.)
- No changes to plugin behavior, commands, agents, scripts, hooks, manifests, or
  templates — documentation only.
- No version bumps or release tags.
- No new screenshots, diagrams, badges, or marketing assets beyond what already
  exists; the worked example is narrated in text/Markdown.
- Re-litigating TP-0011's decisions (CONTRIBUTING extraction, consulting blurb
  wording, command grouping) — this builds on them.

## Open Questions

None — direction is agreed (tce README only; hands-on worked-example walkthrough;
name the objection head-on; state the three value props; speak to individual and
team readers equally).

## Questions for Research/Planning

- [ ] Which existing sections should the new hands-on intro **replace or absorb**
      vs. sit before — in particular the current "Why context engineering?" section
      (keep its four-step list, fold it into the walkthrough, or move it after the
      worked example)?
- [ ] What concrete task should the worked example use so it's representative,
      short, and shows real artifacts without bloating the README? Consider
      dogfooding (a tmt `TP-…` ticket flowing through the chain).
- [ ] How long can the intro grow before it hurts scannability — what's the right
      balance between a persuasive narrative and a fast-to-skim opening (revisit the
      README best practices surfaced in TP-0011's research)?
- [ ] Best phrasing to name the objection without sounding defensive, and where in
      the intro it belongs relative to the worked example and the value props.

## References

- `plugins/tce/README.md` — the document to revise (current intro: lines ~1-57)
- `thoughts/shared/tickets/TP-0011-readme-rework-user-first.md` — prior user-first
  README rework (Done); this ticket builds on its structure and must not regress it
- Author's blog on why the process exists:
  https://schlitt.info/blog/0793_context_engineering_claude_code.html
- Original source feedback (in the ticket-creation conversation): "the process
  looks complex & I cannot see where it helps me…"

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-06-22

Key decisions made during ticket creation:

- **Scope narrowed to the tce README only** (not root/tmt), since the feedback
  targets tce's introduction specifically.
- **Hands-on form = worked-example walkthrough** (one real task through the chain),
  chosen over a bare quickstart command list as the most convincing format for the
  skeptical reader.
- **Name the objection head-on** rather than staying implicitly positive — the
  feedback *is* the objection, so the intro should answer it directly.
- **Speak to individual and team readers equally** — the value props split across
  both audiences (reliability/self-learning land for individuals too; equalization
  is team-level).
- Recognized as a **follow-up to TP-0011** (Done), not a duplicate: TP-0011 fixed
  overall structure and extracted CONTRIBUTING; this sharpens the *intro's*
  motivation and ordering per new feedback, and must not regress TP-0011.
- Complexity **Small**: a single documentation file, focused on its opening, with
  no code or content-preservation risk beyond keeping existing sections intact.
