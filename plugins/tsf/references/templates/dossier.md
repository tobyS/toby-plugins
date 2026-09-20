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
2. The executive summary and its impact rating
3. The dossier skeleton
4. The addendum
5. Rules
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

# The executive summary and its impact rating

The dossier opens with an executive summary, because the reader's first decision
is not "what did it do" but **how much of my attention does this deserve, and
where do I start**. It is three short parts and nothing else:

1. **One sentence on what the pull request does.** Not the narrative — the
   one-line version a reviewer could repeat back.
2. **An impact rating, 1 to 5, and one sentence saying why that number.** The
   rating is about **impact and risk, never effort or line count**: a
   three-line change to an authorization check outranks a thousand-line
   rename.
3. **Optionally, one to three sentences of "start here"** — only when one of the
   impact topics below actually applies — each naming the spot with a permalink,
   so the reader can jump straight to it.

The rating scale, so that a 3 means the same thing on every ticket:

| Rating | What it means |
|---|---|
| **5** | Security-relevant, or changes core domain logic, or is hard to reverse (data migration, external contract). Read it properly. |
| **4** | Touches code that changes often or that many callers depend on, or carries a deviation from the plan that changed what is built. Skim carefully. |
| **3** | An ordinary feature or fix in familiar territory, with real behaviour change. Skim. |
| **2** | Small, local, well covered by tests; the risky part is already proven. Glance. |
| **1** | Mechanical or generated: renames, formatting, comments, dependency bumps with no behaviour change. Approve on the summary. |

The impact topics that justify a "start here" sentence — and that push a rating
up — are exactly these: **security relevance**, **core domain logic**, **code
that changes frequently or has many dependents**, **a plan deviation**, **an
irreversible or externally visible change**, and **a gate verdict or manual item
the factory could not settle**. Anything else belongs further down the dossier,
not in the summary.

Rate honestly. A factory that calls everything a 4 trains the human to ignore
the number, and a 2 on something that later breaks production costs far more
than a minute of over-reading.

# The dossier skeleton

````markdown
# Dossier: GH-[n] — [spec title]

## Summary

[One sentence: what this pull request does.]

**Impact: [1-5]/5** — [one sentence: why that rating, in terms of the impact topics — security, core domain logic, frequently changed or widely depended-on code, a plan deviation, an irreversible or externally visible change, an unsettled verdict.]

**Start here:** [One to three sentences, only when an impact topic applies: what to look at first and why, each spot a permalink.] [`path/to/file.ext:40`](https://github.com/[owner/repo]/blob/[sha]/path/to/file.ext#L40)

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
after a dossier existed, or **a landing that could not be decided** (§9.3
step 4) — appends an **addendum** comment rather than rewriting the dossier:

````markdown
# Dossier addendum: GH-[n] — round [k]

## Summary

[One sentence: what changed since the human's last look.]

**Impact: [1-5]/5** — [unchanged from the dossier, or the new rating and why it moved.]

**Start here:** [Only when the change since the last look deserves it, with a permalink.]

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

## The landing refusal

When the landing reaches step 4 and cannot decide for the merge, the addendum
says exactly what was decided and why. Its "What changed since your last look"
names the cause — one of:

- **the conflict resolution changed behaviour** — the base branch had moved in
  a way that forced a choice, the resolution is classified `logic`, and the
  approval no longer covers the code. Say what the choice was.
- **the integration gate returned risk** — quote its concrete description: what
  in the base branch's delta meets what in this pull request, and what breaks
  between them.
- **the approving review is behind the logic head** — code was pushed after the
  approval, so it is stale.

The closing line is the same fixed re-review copy.

# Rules

- **The summary is the whole point of the top of the document**: one sentence,
  a rated impact, and — only where it is earned — where to start. Never repeat
  the narrative there, and never pad it to look thorough.
- **The rating is impact, not effort.** Size alone never justifies a 4 or 5, and
  a small diff in a dangerous place never justifies a 1 or 2.
- **"Start here" is for the impact topics only.** With none of them in play,
  leave the line out entirely — an empty prompt to look somewhere is worse than
  no prompt.
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
