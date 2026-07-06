---
date: 2026-07-06T11:01:30Z
git_commit: 376019953d6763daae294986c748a98e11c9d25e
branch: main
repository: toby-plugins
topic: "design_explore Phase 1b auto-baseline capture via browser tooling"
tags: [research, tce, design_explore, browser-tooling, capability-detection]
status: complete
last_updated: 2026-07-06
---

# Research: design_explore Phase 1b auto-baseline capture via browser tooling

**Date**: 2026-07-06T11:01:30Z
**Git Commit**: 376019953d6763daae294986c748a98e11c9d25e
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0021: How can `/tce:design_explore` Phase 1b attempt to capture the visual
baseline (desktop + mobile screenshots of existing pages) itself using
whatever browser automation tooling happens to be available in the session,
falling back to the current ask-the-user-for-screenshots flow when no tooling
is available, capture fails, or the user prefers manual — without hardcoding
any specific tool/MCP name, and without weakening the existing hard
requirement that no design work happens without a visual baseline?

## Summary

`plugins/tce/commands/design_explore.md` Phase 1b (`design_explore.md:63-73`)
today unconditionally asks the user to supply screenshots — there is no
branch, no capability check, and no fallback structure, because asking is the
only path. Phase 1c (immediately after) already spawns the four standard
research agents but is explicitly sequenced to start only "with visual
baseline in hand" (`design_explore.md:75`).

The command has an existing, unconditional "show something in a browser"
mechanism in Phase 3 — the `open` shell command
(`design_explore.md:231-240`) — but that is for showing the *agent's own
generated mockups* to the user, a different direction (agent → user) from
what TP-0021 needs (agent navigates to and captures the *existing app's*
pages, i.e. agent → browser → agent).

No capability-detection pattern for optional/environment-dependent tooling
exists anywhere in tce's commands or agents today. The closest precedents are
three variants, none of which is a "detect if a session tool/MCP is loaded"
mechanism:

1. A static "if a configured capability exists, use it, else fall back"
   conditional, worded generically (LSP), repeated across the three codebase
   agents.
2. A one-line "if a skill is available in your environment, you may use it;
   otherwise do X yourself" conditional in `quickfix.md`.
3. An **empirical, try-it-first** pattern in `init.md` — attempt the action,
   and only ask the user if it fails — which is the closest structural match
   to what TP-0021's acceptance criteria describe ("Phase 1b first checks...
   and, if so, offers automated capture before asking").

`work.md`'s "Design exploration check" (2b) and `quickfix.md`'s references to
design_explore both treat `/tce:design_explore` as an opaque external step —
neither re-describes Phase 1b/1c internals — so a change to Phase 1b's
internal mechanics does not, on its own, require edits to `work.md` or
`quickfix.md` (see "Composite Command Impact" below).

## Detailed Findings

### design_explore.md Phase 1b — current hard block

`plugins/tce/commands/design_explore.md:63-73`:

```markdown
### Phase 1b: Visual Baseline — See the Existing UI

**Before proposing any designs, you MUST see what the existing related pages actually look like rendered.** Code research alone is not sufficient — CSS classes can combine in unexpected ways, and you need a visual reference to match the design language faithfully.

Ask the user to provide screenshots of the relevant existing pages (desktop and mobile):

> I need to see the current [page name] on desktop and mobile to match the design language accurately.
>
> Could you share screenshots of the desktop and mobile views?

**Only proceed once you have a visual reference.** Do not skip this step. Code research supplements visual verification — it does not replace it.
```

Structural notes:

- It is a standalone phase between Phase 1 ("Understand the Challenge",
  `design_explore.md:41-61`) and Phase 1c ("Research Current Design State",
  `design_explore.md:75-116`).
- The hard-block rationale ("Code research alone is not sufficient...") is
  stated once here and never repeated verbatim elsewhere, though Phase 1c's
  "Cross-check research against your visual baseline" subsection
  (`design_explore.md:94-97`) depends on it: "Do the classes you found
  produce the layout you SAW? If not, dig deeper."
- The only mechanism offered today for satisfying the block is asking the
  user — no branch, capability check, or automated path exists.
- The rule is stated twice for emphasis: once as a bolded MUST sentence
  (line 65) and once as a closing "Do not skip this step" directive (line 73).

### design_explore.md Phase 1c — sequencing and agent usage (unaffected by this ticket, but the sequencing dependency matters)

`plugins/tce/commands/design_explore.md:75-116`:

- Line 75 declares the ordering dependency explicitly: "**With visual
  baseline in hand, research the codebase to understand the components and
  patterns.**" — Phase 1c is defined to run strictly after Phase 1b's hard
  block is satisfied, regardless of *how* it was satisfied.
- Spawns four agents in this phase: `codebase-locator` (line 81),
  `codebase-analyzer` (line 82), `codebase-pattern-finder` (line 83),
  `thoughts-locator` (line 84).
- "Cross-check research against your visual baseline"
  (`design_explore.md:94-97`) and "Gap detection" against
  `.claude/tce/design-system.md` (`design_explore.md:99-116`) both assume a
  visual baseline already exists by this point — this assumption holds
  equally whether the baseline came from automated capture or manual
  screenshots, so Phase 1c needs no changes.

### design_explore.md Phase 3 — the existing "show in browser" mechanism (different direction, but the only established browser-touching pattern in this command)

`plugins/tce/commands/design_explore.md:231-240`:

```markdown
**Opening mockups in the browser:**

1. If multiple mockups exist, open `index.html`; otherwise open the single mockup file
2. Always use the `open` command to open mockups:
   ```bash
   open /absolute/path/to/thoughts/shared/mockups/<YYYY-MM-DD>-<slug>/index.html
   ```
3. Print the command to the user so they can re-open it later:
   > Opened in your default browser. To reopen:
   > `open /absolute/path/to/mockup.html`
```

- This unconditionally shells out to the macOS `open` binary — no
  cross-platform branch, no tool-detection. It is also stated as a top-level
  rule: `design_explore.md:25` — "Mockups are standalone HTML files opened in
  the default browser via `open`" (CRITICAL RULES block).
- This is the *agent showing its own output to the user* (agent → browser,
  one-way, no capture). TP-0021 needs the reverse direction plus a read-back:
  the agent needs to navigate to the *existing app's* pages and capture what
  renders (agent → browser → screenshot → agent), which is a fundamentally
  different capability (browser automation/screenshot tooling, not `open`).
  These two mechanisms do not overlap and Phase 3 needs no changes.

### CRITICAL RULES and Project context — house style for hard rules and agnosticism

`plugins/tce/commands/design_explore.md:11-18` (Project context) does not
contain "stack-agnostic" or "ticket-system-agnostic" language the way
`work.md:14` / `quickfix.md:13` do — it only names the plugin and points at
`.claude/tce/design-system.md` / `.claude/tce/tickets.md`. It never reads
`.claude/tce/profile.md`. The closest agnosticism statement is the
`[PREFIX]-XXXX` placeholder definition (lines 16-18).

`plugins/tce/commands/design_explore.md:20-27` (CRITICAL RULES):

```markdown
- This command creates **visual mockups only** - no production code, no backend integration
- All mockups must faithfully reproduce the application's **current** design language
- The live codebase is the source of truth — not the reference file alone
- Mockups are standalone HTML files opened in the default browser via `open`
- Always get user confirmation before moving between phases
- Never skip the discussion phase — always propose approaches before building mockups
```

Line 24 ("The live codebase is the source of truth — not the reference file
alone") is echoed in the "Guidelines" section under "Codebase Is the Source
of Truth" (`design_explore.md:341-346`).

House convention for CRITICAL/hard-rule phrasing across the repo (not
specific to this file): a bold lead sentence (`**CRITICAL: ...**` or `##
CRITICAL ...` heading) stating an absolute (MUST / Do NOT / Never skip),
frequently paired with a rationale clause after an em-dash, and often
restated as an explicit anti-shortcut sentence at the end of the block. Seen
at `design_explore.md:20-27,65-73`, `quickfix.md:129-183`, `plan.md:111,444`,
and the shared three-part agent envelope in `codebase-locator.md:31`,
`codebase-analyzer.md:37`, `codebase-pattern-finder.md:36`,
`plan-compliance-checker.md:28`. Any rewording of Phase 1b's hard block
should preserve this shape — a change described purely as "add a branch"
without keeping the bold-MUST / anti-shortcut framing would read as a
weakening even if the underlying rule is unchanged.

### No capability-detection pattern exists yet in tce — three related precedents

**1. Generic "if a configured capability exists, use it" conditional (LSP)** —
byte-identical across the three codebase agents:

`plugins/tce/agents/codebase-locator.md:14-16` (repeated verbatim in
`codebase-analyzer.md:14-16` and `codebase-pattern-finder.md:14-16`):

```markdown
## LSP Tool - For Symbol-Based Location

If the project's languages have a configured **Language Server Protocol (LSP)** server, use LSP when searching for specific symbols:
```

And echoed in prose at `codebase-pattern-finder.md:81`: "Use your `Grep`,
`Glob`, and `LS` tools (and LSP where available) to find what you're looking
for..."

Characteristics: names the *capability* generically (never a specific LSP
implementation), phrased as "if X is configured, use X" with the
always-available fallback (Grep/Glob) already present in the surrounding
text. Per this repo's convention (see `CLAUDE.md`'s note on the duplicated
AskUserQuestion block), shared conditional text like this is kept as
byte-identical duplication across the files that need it, not factored into a
shared reference — there is no cross-agent shared-text mechanism in this
repo.

**2. One-off "if a skill is available... otherwise do it yourself" conditional**:

`plugins/tce/commands/quickfix.md:254`:

```markdown
6. **Clean up before the final implementation commit** if you iterated through multiple approaches during implementation: remove leftover artifacts of abandoned attempts (dead code, unused helpers, stale comments). If a simplify/cleanup skill is available in your environment, you may use it; otherwise review the diff yourself.
```

Characteristics: no skill is named by product name ("a simplify/cleanup
skill" is a capability description); the fallback is stated in the same
sentence.

**3. Empirical "try it, ask only on failure" pattern** — the strongest
existing precedent for TP-0021's "offers automated capture before asking"
shape:

`plugins/tce/commands/init.md:290-293`:

```markdown
For non-file ticket systems, **verify access before writing**: ask the user for
an existing ticket reference and try the read mechanism (e.g. `gh issue view 123`,
the Jira CLI/MCP call). If it fails, resolve tooling/auth with the user now —
`tickets.md` must only document mechanisms that actually work.
```

This is closer in shape to what TP-0021 needs than the LSP pattern: it
detects capability by *attempting the action* rather than by static
introspection of what's "configured," and only escalates to the user on
failure. TP-0021's phrasing ("Phase 1b first checks whether browser
automation tooling is available... and, if so, offers automated capture
before asking the user") suggests a similar shape: attempt (or offer to
attempt) capture, and fall back to asking when there's nothing to attempt
with, the attempt fails, or the user prefers manual.

**No session/tool-discovery mechanism** (enumerating currently loaded
skills/MCP servers, or a ToolSearch-style capability list) is referenced or
described anywhere in `plugins/tce/commands/*.md` or `plugins/tce/agents/*.md`.
The only established "Skill tool" usage in tce is invoking a known,
always-present sibling command by its namespaced name (e.g. `tce:plan` in
`quickfix.md:21`, `work.md:22`) — not detecting whether an *optional*
capability exists. This confirms the ticket's own note (line 71-73): "tce has
no capability-detection pattern yet; this ticket establishes it."

There is no `.claude/skills/` directory or any MCP/tool declaration in this
repo's plugin manifests (`plugins/tce/.claude-plugin/plugin.json`'s only
field beyond the standard ones is `userConfig.show_setup_reminders`) —
browser automation tooling (Claude in Chrome, a Chrome DevTools MCP,
Playwright, or similar, per the ticket) is entirely external/global to this
repo, consistent with the ticket's requirement that the command describe the
capability generically rather than naming a specific tool.

### "Ask only for what's missing" phrasing precedents (for the "ask the user only for what it can't know" acceptance criterion)

`plugins/tce/commands/quickfix.md:166`: "**Only ask the user if there are
genuine ambiguities or design decisions** that cannot be resolved from the
available information..."

`plugins/tce/commands/plan.md:94-104`: a bullet list of specific, named
conditions under which asking (or re-researching) is warranted, framed with
an explicit "only":

```markdown
- Only ask clarifying questions about **requirements and design decisions**, not about codebase structure

**Only conduct fresh research or source-file reads if:**

- No research document exists for the ticket
- The user explicitly requests fresh research
- The research document is outdated (check `last_updated` in frontmatter vs recent code changes)
- A **specific implementation detail is missing** that the research didn't cover (spawn one targeted sub-task only for that detail)
- You have a specific question about a file that the research doesn't address (read just that file)
```

The recurring shape across the repo is a bullet list of specific, named
conditions with an explicit "only" framing — not a blanket "ask everything"
nor "ask nothing." A rewritten Phase 1b should follow this shape for what it
asks the user when it can't determine something itself (app URL, dev server
startup, auth/login), matching TP-0021's acceptance criterion.

### work.md's "Design exploration check" (2b) — does not re-describe Phase 1b/1c

`plugins/tce/commands/work.md:117-129`:

```markdown
### 2b. Design exploration check

If the ticket involves a non-trivial UX change (new UI patterns, significant flow changes, layout redesigns — NOT bug fixes, text changes, or simple CRUD following established patterns):

1. Check if a design decision already exists:

   ```bash
   grep -rl "[PREFIX]-XXXX" thoughts/shared/mockups/*/DECISION.md 2>/dev/null
   ```

2. If a DECISION.md exists: incorporate it and continue
3. If no design decision exists: add this to the questions for the user
```

This only checks for a pre-existing `DECISION.md` and, if absent, defers the
choice of whether to run `/tce:design_explore` to the user via
`AskUserQuestion` (`work.md:162-167`, verbatim question block: "Run
/tce:design_explore before planning?"). It never re-describes design_explore's
internal phases (1, 1b, 1c) — it treats the command as opaque and hands
control to the user if chosen.

### quickfix.md — no dedicated section, defers to plan.md's check

`quickfix.md` has no "Design exploration check" section. Its two references
are both indirect, pointing at `/tce:plan`'s own check rather than
reproducing it:

- `quickfix.md:168` (Phase 4, "Autonomy overrides for quickfix context"): "If
  the design-exploration check in `/tce:plan` flags a non-trivial UX change,
  that is a signal the fix is bigger than a quickfix..."
- `quickfix.md:249` (Important Rules #1): "...or `/tce:plan` flags a
  non-trivial UX change needing `/tce:design_explore`, STOP and tell the
  user..."

The actual check quickfix defers to lives in `plugins/tce/commands/plan.md`:
the design-decision-exists check and the "Would you like to run
`/tce:design_explore` first..." dialog (`plan.md:263,267,271`), plan.md's
table row (`plan.md:50`): "*(Optional)* Explore and select a visual design
for UX changes."

Since quickfix delegates planning to the `tce:plan` skill
(`quickfix.md:161`), it inherits `/tce:plan`'s check by delegation rather
than re-describing it, escalating a flagged non-trivial UX change to the user
(stop) rather than branching interactively itself.

### Composite Command Impact

Neither `work.md` nor `quickfix.md` re-describes design_explore's Phase 1b/1c
mechanics inline — both treat `/tce:design_explore` as an opaque external
command and only reference *whether to run it at all*. Per this repo's
composite-tracking rule (`CLAUDE.md`, "Composite commands must track the
single-step commands"), a change to Phase 1b's *internal* capture mechanism
does not by itself require edits to `work.md` or `quickfix.md`, because
neither mirrors that content. This should be reconfirmed at planning time
against the final wording chosen (in case the change introduces something —
e.g. a new outward-facing behavior change the composites' own dialogs should
mention — that the composites would need to reflect), but no existing
mirrored text was found that this ticket's scope touches.

## Code References

- `plugins/tce/commands/design_explore.md:63-73` - Phase 1b, the current hard block to be modified
- `plugins/tce/commands/design_explore.md:75-116` - Phase 1c, unaffected but sequenced after 1b
- `plugins/tce/commands/design_explore.md:231-240` - Phase 3's `open`-based "show mockup in browser" mechanism (different direction, not reused)
- `plugins/tce/commands/design_explore.md:20-27` - CRITICAL RULES block (house style reference)
- `plugins/tce/commands/design_explore.md:11-18` - Project context section
- `plugins/tce/agents/codebase-locator.md:14-16` - LSP "if configured, use it" conditional pattern (repeated in codebase-analyzer.md:14-16, codebase-pattern-finder.md:14-16)
- `plugins/tce/commands/quickfix.md:254` - "if a skill is available... otherwise do it yourself" one-off conditional
- `plugins/tce/commands/init.md:290-293` - "try it, ask only on failure" empirical capability check (closest precedent)
- `plugins/tce/commands/quickfix.md:166` - "only ask if genuine ambiguity" framing
- `plugins/tce/commands/plan.md:94-104` - bullet-listed "only ask/re-research if" conditions
- `plugins/tce/commands/work.md:117-129` - Design exploration check (2b), opaque reference to design_explore
- `plugins/tce/commands/quickfix.md:168,249` - indirect references deferring to plan.md's check
- `plugins/tce/commands/plan.md:50,263,267,271` - the actual design-decision-exists check quickfix defers to
- `thoughts/shared/tickets/TP-0021-design-explore-auto-baseline.md` - the ticket
- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:245-248` - the review item this ticket was created from

## Architecture Documentation

tce commands are markdown prompt files with no runtime code — "capability
detection" here can only ever be prose instructing the model to attempt an
action (e.g. try navigating a browser tool to a URL) and interpret the
runtime result (tool available and succeeded / tool unavailable or failed),
not a scriptable check. The `init.md:290-293` precedent (try the ticket-read
mechanism, resolve on failure) is the established shape for this in the repo
and is the strongest structural template for TP-0021's Phase 1b rewrite. The
LSP conditional (`codebase-locator.md:14-16` etc.) is the established shape
for *static* "if configured" conditionals but is a weaker match since it
doesn't involve an attempt/fallback-on-failure loop.

## Historical Context (from thoughts/)

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:245-248`
  is the sole origin of this ticket ("Smaller usability notes", item 2):
  "`design_explore` hard-blocks on user-supplied screenshots
  (`design_explore.md:62-72`). When browser tooling (Claude in Chrome,
  chrome-devtools MCP, Playwright) is available it could offer to capture the
  baseline itself, with the manual path as fallback." The ticket's Problem
  Statement and Desired Outcome closely mirror this note's wording.
- No prior research or plan document exists for this topic
  (`thoughts/shared/research/` and `thoughts/shared/plans/` have no
  TP-0021-prefixed files before this one).
- No `thoughts/shared/mockups/*/DECISION.md` files exist in the repo — no
  prior design-exploration sessions to draw a precedent from for how browser
  tooling might have been used previously.

## Related Research

None — this is the first research document for TP-0021.

## Open Questions

These map to the ticket's own "Questions for Research/Planning" section
(lines 69-77) and are left for the planning phase to resolve, per tce's
research/plan boundary:

1. **How to phrase generic capability detection** — research found no
   existing "detect a session tool/MCP at runtime" mechanism to reuse
   directly; the closest precedents (LSP static-conditional,
   `init.md`'s try-it-first) point toward an empirical "attempt navigation
   and screenshot capture; treat failure or absence as unavailable" phrasing,
   but the exact wording is a planning decision.
2. **Desktop and mobile viewport widths for the captures** — not addressed by
   any existing tce file; Phase 3's mockup-rendering rules
   (`design_explore.md:203-221`) use `max-width: 390px` for mobile mockup
   scenes as a reference number for what "mobile width" means elsewhere in
   this same command, which may or may not be the right width for capturing
   the *real* app's rendered pages.
3. **Where the app URL comes from** — always ask vs. optionally record a
   dev-server URL in `.claude/tce/profile.md`. Research found no existing
   profile.md field for this and no precedent for design_explore reading
   `profile.md` at all (it currently never does, see Project context
   analysis above); adding one would touch init/refresh sync rules per
   `CLAUDE.md`'s "Migrations & version markers" and "`/tce:refresh`
   re-analysis" rules — a real cost the ticket already flags as "weigh cost
   vs benefit."
