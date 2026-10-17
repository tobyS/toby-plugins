<!--
Runtime reference for the commands that run work-loop.md. Read at the point of use —
always in full, even if already read earlier in the session — by the `verifier`
agent in `mode: dossier` before it writes the dossier. Never copied into
consuming projects. Ported from tsf's dossier template, without its factory
parts (issue paths, comment timestamps, the addendum, the review gesture, the
impact rating).

Changes to this file are command-contract changes under the CLAUDE.md rule
"tce: /tce:work is an orchestrator": the counted-facts line is read by
work-loop.md's closeout summary, so a change to it or to the filename updates
this file, plugins/tce/agents/verifier.md and work-loop.md in the same commit.

Contents:
1. What the dossier is for
2. Where it lives
3. The dossier skeleton
4. Counting the facts
5. Permalinks and evidence
6. Rules
-->

# What the dossier is for

The dossier is the human's entry point to a finished change: it concentrates
scarce attention where the run — which knows where the bodies are buried — says
it matters. It is written for someone deciding *whether* and *where* to look
deeper, not as documentation of everything that happened. Two minutes to read.

# Where it lives

`thoughts/shared/dossiers/YYYY-MM-DD-[PREFIX]-XXXX-<slug>.md` — the date of
writing, the canonical ticket ID, and the plan's slug. For a ticketless intent
(`ticket: none`): `thoughts/shared/dossiers/YYYY-MM-DD-<slug>.md` — the date of
writing and the intent's slug, with no suffix. It is committed on the
branch the work is on. Under **Pull request** delivery its text is posted as-is
as the pull request's body; otherwise /tce:work prints it.

# The dossier skeleton

For a ticketless intent the heading is `# Dossier: <slug> — [intent title]`.

````markdown
# Dossier: [PREFIX]-XXXX — [ticket title]

## Summary

[One sentence: what this change does — the one-line version a reviewer could
repeat back.]

Criteria met [n]/[m] · fix rounds [r] · tests added [t] · decisions made for you [d] · for you to check [c]

**Start here:** [One to three sentences, only when something deserves eyes
first: what to look at and why, each spot a permalink.] [`path/to/file.ext:40`](https://[forge]/[owner/repo]/blob/[sha]/path/to/file.ext#L40)

## What was built

[The condensed narrative: what changed, the crucial decisions, the obstacles
worked around. Three to six sentences. No step list, no transcript.]

## Where to look

- [`path/to/file.ext:12-40`](https://[forge]/[owner/repo]/blob/[sha]/path/to/file.ext#L12-L40) — [one sentence on *why* this spot deserves eyes: the risky part, the judgment call, the irregular bit]

## Decided for you

- **[decision]** — over [rejected alternative]: [why]

## For you to check

- [ ] [item] — run `[exact command]` (or: [exact step]); pass looks like
  [observable result]. [Why the run could not settle it: credentials, a
  third-party system, visual or subjective judgment, a decision.]

## Concerns

- [A concern an agent returned with `done with concerns`, one line, with where
  it applies.]

## Artifacts

- Intent: `[path]`
- Research: `[path]`
- Plan: `[path]` (its `## Verification` section holds the evidence per criterion)
````

Sections that have nothing to say read `None.` — never drop one, so the human
learns that the run looked.

# Counting the facts

Every number in the counted-facts line is counted from disk, never estimated:

- **Criteria met `n/m`** — from the plan's `## Verification` section: `m` is
  the number of criteria listed, `n` those verified as met (by the checker or
  by the verifier's own attempt).
- **Fix rounds `r`** — the sum of every phase log's `Fix rounds` and the last
  phase's `Final fix rounds` (the `n` of each `n/3`).
- **Tests added `t`** — test cases added in the implementation diff, counted
  by the project's own convention for what a test is (a new test function,
  case or spec block). `0` is a valid, reportable answer.
- **Decisions made for you `d`** — the `*(decided for you)*` lines in the
  plan's `## Decisions`. A plan without that section counts `0`.
- **For you to check `c`** — the items in `## For you to check`.

# Permalinks and evidence

- When the remote is a known forge, link files at the commit SHA the dossier is
  written at (`git rev-parse HEAD`), with line ranges, so the link keeps
  meaning after the branch is deleted. Otherwise write `path:line` and state
  the SHA once under the summary.
- **Line numbers are the post-change source's, never a diff's.** Get the real
  number by reading the file at head, or by counting forward from the `+` side
  of a hunk header. Sanity-check it against the file's length before citing.

# Rules

- **The summary is the whole point of the top of the document**: one sentence,
  the counted-facts line, and — only where it is earned — where to start.
  Never repeat the narrative there.
- **"Start here" only when something deserves it**: security relevance, core
  domain logic, code that changes often or has many dependents, a deviation
  from the plan, an irreversible or externally visible change, or a criterion
  the run could not settle. With none of these in play, leave the line out.
- **Every "where to look" entry earns its place** with a reason. A list of
  every changed file is not curation.
- **Never claim a verification that did not run.** An item the run attempted
  carries its evidence in the plan's `## Verification`; an item it could not
  attempt is under "For you to check" with the reason.
- **"Decided for you" is copied, not composed**: the plan's
  `*(decided for you)*` lines, without the marker.
- Phrase the dossier for the `## Reader` section of `profile.md`, as the brief
  is.
