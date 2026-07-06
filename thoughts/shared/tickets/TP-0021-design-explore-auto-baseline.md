# TP-0021: design_explore captures the visual baseline itself when browser tooling is available

**Status:** In Progress
**Estimated Complexity:** Small
**Created:** 2026-07-03
**Updated:** 2026-07-03

## Problem Statement

`/tce:design_explore` Phase 1b hard-blocks on the user: "Ask the user to provide
screenshots of the relevant existing pages (desktop and mobile)… Only proceed
once you have a visual reference. Do not skip this step." The visual baseline
itself is the right requirement — CSS classes combine unpredictably and mockups
must match the rendered reality — but making the user go take screenshots by
hand is unnecessary friction whenever browser automation tooling (Claude in
Chrome, a Chrome DevTools MCP, Playwright, or similar) is available to the
session and the app can be reached in a browser.

## Desired Outcome

Phase 1b tries to capture the baseline itself first: if browser tooling is
available, the command offers to navigate to the relevant pages and take the
desktop and mobile screenshots automatically (asking the user only for what it
can't know, e.g. the app's URL or how to log in). The existing ask-the-user path
remains as the fallback when no tooling is available, capture fails, or the user
prefers to provide screenshots. The hard requirement — no design proposals
without a visual reference — is unchanged.

## User Stories / Use Cases

- As a tce user with browser tooling connected, I want design_explore to grab
  the baseline screenshots itself so that I only confirm they show the right
  pages.
- As a tce user without browser tooling (or with an app the agent can't reach),
  I want the current manual-screenshot flow, unchanged.
- As a tce user, I still never want mockups designed blind — the baseline
  requirement stays hard.

## Acceptance Criteria

- [ ] Phase 1b first checks whether browser automation tooling is available in
      the session and, if so, offers automated capture before asking the user
      for screenshots.
- [ ] Automated capture takes both a desktop and a mobile-width view of each
      relevant page, and the user confirms the captures show the right state
      before the command proceeds.
- [ ] The command asks the user for whatever it cannot determine itself (app
      URL, running the dev server, auth) rather than guessing.
- [ ] The manual path remains fully intact as the fallback (no tooling, capture
      failure, or user preference).
- [ ] No hard dependency on any specific tool/MCP is written into the command —
      it describes the capability generically and uses whatever is present
      (core design rule: the plugin stays project- and environment-agnostic).
- [ ] The "no design work without a visual baseline" rule is preserved verbatim.

## Out of Scope

- Starting/serving the user's app automatically (the command may ask the user
  to start it).
- Any change to later phases (mockup creation, iteration, DECISION.md).
- Storing captured screenshots as workflow artifacts (nice-to-have; decide in
  planning, not required).

## Open Questions

None — "try to get the screenshots itself first, fall back to asking" was
confirmed at ticket creation.

## Questions for Research/Planning

- [ ] How a command can detect available browser tooling generically (tool
      presence at runtime) without naming specific MCP servers — tce has no
      capability-detection pattern yet; this ticket establishes it.
- [ ] Sensible viewport widths for the desktop and mobile captures.
- [ ] Where the app URL should come from: always ask, or optionally record a
      dev-server URL in `.claude/tce/profile.md` (would touch init/refresh
      sync rules — weigh cost vs benefit).

## References

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — Section 4, item 2.
- `plugins/tce/commands/design_explore.md` — Phase 1b (the hard block).
- `CLAUDE.md` — core design rule (project-agnostic plugins; no tool literals).

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-07-03
Created from the independent plugin review (Fable 5) discussion. The user
confirmed the command should attempt capture itself first; the manual flow
stays as fallback. Establishing a generic capability-detection wording (no
tool-name literals) is the main design work here.
