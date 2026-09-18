<!--
Runtime reference for the tsf software factory. Read at the point of use —
always in full, even if already read earlier in the session — by the tsf:dossier
agent before it writes the dossier, and by /tsf:cycle before it posts one. Never
copied into consuming projects.

Changes to this file are command-contract changes: the closing line tells the
human how to respond and is what makes the review gesture unambiguous, so
changing it requires updating plugins/tsf/agents/dossier.md and
plugins/tsf/references/cycle-dispatch.md (row 10) in the same commit.

Contents:
1. What the dossier is for
2. The dossier skeleton
3. The addendum
4. Rules
-->

# What the dossier is for

The dossier is the human's entry point to a finished change: it concentrates
scarce attention where the factory — which knows where the bodies are buried —
says it matters. It is written for someone deciding *whether* to look deeper,
not as documentation of everything that happened. Two minutes to read.

It lives at `thoughts/factory/GH-<n>/reports/dossier.md` on the ticket branch and
is posted to the pull request as a comment by the factory identity. The dossier
comment's `created_at` is a reference point of the state machine (§4 row 10): a
changes-requested review counts when it is newer than the factory's last dossier
or addendum comment.

# The dossier skeleton

````markdown
# Dossier: GH-[n] — [spec title]

## What was built

[The condensed narrative: what changed, the crucial decisions, the obstacles
worked around. Three to six sentences. No step list, no transcript.]

## Where to look

- [`path/to/file.ext:12-40`](https://github.com/[owner/repo]/blob/[sha]/path/to/file.ext#L12-L40) — [one sentence on *why* this spot deserves eyes: the risky part, the judgment call, the irregular bit]

## Open items

- [A gate verdict that needs a person, with what the gate could not see]
- [An advisory security finding, with its evidence]
- [A plan deviation, naming the addendum that records it]
- [A manual verification item that could not be attempted, and why]

[Manual items the factory *did* attempt appear here only if they failed or were
inconclusive — with the evidence. An item that was attempted and passed is not
an open item; say so in "What was built" if it is interesting.]

## Overlapping work

- [Another open factory pull request touching the same files or modules, and
  what the combination would need a second look for. "None." when there is no
  overlap.]

## How to respond

Approve this pull request, or request changes with a native review — that review is the factory's signal. Anything else belongs on issue #[n]: free-text comments on this pull request are not read.
````

# The addendum

A later round — a rework, a fix, a verification episode that changed the code
after a dossier existed — appends an **addendum** comment rather than rewriting
the dossier:

````markdown
# Dossier addendum: GH-[n] — round [k]

## What changed since your last look

[Two to four sentences: what the review asked for or what the gate caught, and
what was done about it.]

## Where to look

- [permalink] — [why]

## Open items

[As above; omit sections that are unchanged and say so.]

Please re-review: the code has moved since your approval, so the previous one no longer covers it.
````

The addendum is committed to `reports/dossier.md` as an appended section as well,
so the branch carries the whole history.

# Rules

- **Permalinks, not paths**: link the file at the commit sha, with line ranges,
  so the link keeps meaning after the branch is deleted.
- **Every "where to look" entry earns its place** with a reason. A list of every
  changed file is not curation.
- **Never claim a verification that did not run.** An item the factory attempted
  carries its evidence; an item it could not attempt says why.
- **The closing line is fixed copy** — it is how the human knows which gesture
  the factory reads.
- No angle brackets and no fenced code blocks in the comment body: it travels
  through the dispatcher as text.
