# TP-0011: Rework all READMEs into user-first docs and extract CONTRIBUTING.md

**Status:** Done
**Estimated Complexity:** Medium
**Created:** 2026-06-16
**Updated:** 2026-06-16

## Problem Statement

The three READMEs in this repo — the marketplace `README.md` and the two plugin
READMEs (`plugins/tce/README.md`, `plugins/tmt/README.md`) — are the only
documentation the plugins have, yet they read like reference/design documents
rather than user-facing docs. They mix usage information with development and
design-rationale content, lead with mechanics instead of value, and don't follow
README best practices. A new user landing on any of them does not immediately
grasp what the plugin does for them or how to get started fastest. The author's
consulting practice (rent-the-toby.com) is also only present as a bare link in
headings, not actually advertised.

## Desired Outcome

All three READMEs are rewritten to be user-first, easy to read and follow, and
best-practice-aligned, while remaining exhaustive as the *only* usage
documentation:

- A reader understands the plugin's value within the first few lines, then has
  the easiest possible path to install and first use.
- Each README contains **usage information only**. All "how to develop the plugin
  itself" content is moved out to a single repo-root `CONTRIBUTING.md`, linked
  from the very bottom of each README.
- rent-the-toby.com is advertised prominently (high in each README) using an
  agreed blurb, but never in the heading.
- The `tce` README adopts the heading `tce — Toby Context Engineering`, and its
  command listing leads with the most important commands and groups the rest by
  role.

## User Stories / Use Cases

- As a developer evaluating a plugin, I want to understand its value in the first
  few lines so that I can decide quickly whether it's for me.
- As a new user, I want the shortest possible install-and-first-use path so that I
  can try the plugin with minimal friction.
- As an existing user, I want exhaustive usage docs in one place so that the
  README remains my complete reference.
- As a potential client, I want to discover that the author offers consulting and
  mentoring so that I can reach out (rent-the-toby.com).
- As a contributor, I want development/release/design-rule guidance in a dedicated
  CONTRIBUTING.md so that contribution docs aren't tangled into user docs.

## Acceptance Criteria

- [ ] All three READMEs are restructured to lead with value (what it is / why you
      want it) before any setup or mechanics, following README best practices
      surfaced in research.
- [ ] Each README contains usage information only; no "how to develop the plugin"
      content remains in any README.
- [ ] A single repo-root `CONTRIBUTING.md` exists and absorbs the development
      content (currently mainly the marketplace README's "Development" section:
      repo layout, update gating, validate & release). It is framed as a
      human-facing contributor guide and references `CLAUDE.md` for the deeper
      agent-facing rules rather than duplicating them.
- [ ] Each of the three READMEs links to `CONTRIBUTING.md` from the very bottom.
- [ ] The agreed rent-the-toby.com blurb (below) appears high in each README
      (same blurb across all three) and is **not** in any heading. Existing bare
      rent-the-toby.com references in headings/subtitles are removed or relocated.
- [ ] The `tce` README heading reads exactly `tce — Toby Context Engineering`.
- [ ] The `tmt` README heading remains `tmt — Toby Markdown Tickets` (already in
      this form — confirm, don't regress).
- [ ] The `tce` command listing is ordered/grouped by importance and role:
      core chain first (`ticket`, `research`, `plan`, `implement`), then shortcuts
      (`work`, `quickfix`), then helpers (`discuss`, `review`, `commit`,
      `design_explore`), then maintenance (`init`, `refresh`). Whether to use one
      table or multiple grouped tables/sections is decided in research/planning
      per best practice (the author is explicitly open on this).
- [ ] All cross-links between the READMEs and to `CONTRIBUTING.md` resolve, and no
      factual usage detail present today is lost in the rewrite (commands,
      requirements, install/update/setup steps, migration notes, ticket format).
- [ ] `claude plugin validate .`, `claude plugin validate ./plugins/tce`, and
      `claude plugin validate ./plugins/tmt` still pass (READMEs aren't validated,
      but nothing structural should break).

## Agreed rent-the-toby.com blurb

The same callout is used high in all three READMEs (placed under the intro, not in
the heading):

> **Built by Toby.** These plugins come out of my daily practice helping
> engineering teams turn experimental AI use into structured, sustainable
> workflows. Need a sparring partner for the hard technical and AI-adoption calls?
> Find me at [rent-the-toby.com](https://rent-the-toby.com).

(rent-the-toby.com is Tobias Schlitt's consulting & mentoring practice — "Real
Trade-offs · Consulting & Mentoring": technical sparring, business-engineering
translation, and AI/agentic workflow adoption.)

## Out of Scope

- No changes to plugin behavior, commands, scripts, hooks, manifests, or
  templates — documentation only.
- No version bumps or release tags (no plugin code changes).
- `CLAUDE.md` is not replaced or removed; it remains the source of truth for the
  deep agent-facing rules. CONTRIBUTING.md references it, not duplicates it.
- No new website/marketing copy beyond the agreed rent-the-toby.com blurb.
- Per-plugin CONTRIBUTING.md files (decided against — one root CONTRIBUTING.md).

## Open Questions

None — direction is agreed (one root CONTRIBUTING.md; human guide that points to
CLAUDE.md; single shared rent-the-toby.com blurb, AI-workflow variant; tce heading
and command grouping as specified).

## Questions for Research/Planning

- [ ] What are current README best practices to apply here (structure, ordering,
      value-first openings, badges, tables vs. grouped sections, length vs.
      scannability)? Use the web research path.
- [ ] Single command table vs. multiple grouped tables/sections for `tce` — which
      best serves scannability and the requested importance ordering?
- [ ] Which existing README content is "usage" vs. "development"? In particular,
      classify the tce README's "How project parameterization works" and "Agents"
      sections, and the tmt README's "Ticket format" / "Using tmt with tce"
      sections — confirm they stay as usage.
- [ ] Exactly which content moves into `CONTRIBUTING.md` (the marketplace README's
      "Development" subsections: two-names note, repo layout, update gating,
      validate & release) and how it should reference `CLAUDE.md` / the existing
      "Testing changes" and "Releasing" sections there.
- [ ] Where precisely should the rent-the-toby.com blurb sit in each README for
      "high position" without burying the value proposition or the quick start?

## References

- Current docs: `README.md`, `plugins/tce/README.md`, `plugins/tmt/README.md`
- `CLAUDE.md` — repository instructions / dev rules CONTRIBUTING.md will point to
- rent-the-toby.com — author's consulting & mentoring practice (advertised)

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-06-16

Key decisions made during ticket creation:

- **One root `CONTRIBUTING.md`** (not per-plugin), framed as the human contributor
  guide that references `CLAUDE.md` for deep agent-facing rules rather than
  duplicating them.
- **All "develop the plugin itself" content leaves the READMEs**; each README
  links CONTRIBUTING.md from the very bottom.
- **Single shared rent-the-toby.com blurb** across all three READMEs (AI-workflow
  variant, recorded above), placed high but never in a heading.
- **tce heading** → `tce — Toby Context Engineering`; **tmt heading** already
  `tmt — Toby Markdown Tickets`.
- **tce command listing** reordered by importance/role (core → shortcuts →
  helpers → maintenance); single-vs-multiple-tables left to research/planning per
  best practice (author explicitly unsure).
- Complexity **Medium**: three docs rewritten plus a new CONTRIBUTING.md, content
  preservation, and a best-practices research pass — substantial but
  documentation-only and well-scoped.
