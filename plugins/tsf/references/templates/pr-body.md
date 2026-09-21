<!--
Runtime reference for the tsf software factory. Read at the point of use —
always in full, even if already read earlier in the session — by the
tsf:implement agent when its final fresh batch writes the pull request's text,
and by the tsf:dossier agent when it validates the live pull request and
corrects that text. The dispatcher never reads it: the pull request's text is an
agent artifact that reaches gh-write.sh by path (cycle.md invariant 3). Never
copied into consuming projects.

Changes to this file are command-contract changes: the title is the squash
commit's subject (DESIGN.md §9.3), the closing keyword is what closes the issue
on merge, and the file's shape is what gh-write.sh --pr-file parses, so
changing any of them requires updating plugins/tsf/agents/implement.md,
plugins/tsf/agents/dossier.md, plugins/tsf/scripts/gh-write.sh,
plugins/tsf/scripts/gh-read.sh and plugins/tsf/references/cycle-write-phase.md
in the same commit (CLAUDE.md "tsf: the pull request's text is an agent
artifact").

Contents:
1. The file
2. The title
3. The body skeleton
4. Rules
-->

# The file

The pull request's text lives in one committed file on the ticket branch,
`thoughts/factory/GH-[n]/pr-body.md`, in exactly this shape:

- **line 1** — the title, on its own, with no heading marker;
- **line 2** — empty;
- **line 3 onward** — the body.

`gh-write.sh pr-create`, `pr-edit` and `merge` take it with `--pr-file` and split
it there, and `gh-read.sh pr --out` writes the live pull request in the same
shape, so a copy of the live text and the committed file compare line by line.
A file whose first line is empty or whose second line is not is refused.

The implement agent writes it in the batch that finishes the plan; the dossier
agent rewrites it when the live pull request does not match this template. It
is committed like any other artifact and excluded from the pull request's diff
with the rest of `thoughts/`.

# The title

```
[type](GH-[n]): [the spec's title, imperative, under 72 characters]
```

`[type]` follows the project's commit convention from `.claude/tsf/config.md`
(`feat`, `fix`, `refactor`, `docs`, …). This title becomes the **squash commit's
subject** when the factory lands the change, so it is written for the main
branch's history, not for the pull request page. A project whose convention is
not Conventional Commits uses that convention's shape instead, keeping the
canonical ticket ID `GH-[n]` in it.

# The body skeleton

````markdown
Closes #[n]

## What this does

[Two to four sentences from the spec's desired outcome — what is observably
true once this is merged.]

## Decisions

- **[Decision]** — [why]. Rejected: [the alternative, one line].

## Artifacts

- [spec](https://github.com/[owner/repo]/blob/[branch]/thoughts/factory/GH-[n]/spec.md)
- [research](https://github.com/[owner/repo]/blob/[branch]/thoughts/factory/GH-[n]/research.md)
- [plan](https://github.com/[owner/repo]/blob/[branch]/thoughts/factory/GH-[n]/plan.md)
- [journal](https://github.com/[owner/repo]/blob/[branch]/thoughts/factory/GH-[n]/journal.md)

The review dossier follows once verification and the gates are green; this pull request is not ready for review until then.
````

# Rules

- **`Closes #[n]` comes first** and is never omitted: it is what closes the issue
  when the squash merge lands.
- **Never a draft.** The pull request is opened ready; CI runs on every push, and
  `tsf:needs-review` on the issue — not the draft flag — is the review signal.
- The **Decisions** section is the plan's decisions, one line each, not the
  increment list. The plan is one click away in Artifacts.
- The closing sentence stays: it tells a human who wanders onto the pull request
  early why there is no dossier yet.
- The title and body come from the spec's title and desired outcome and the
  plan's decisions — which is exactly why an agent writes them and the
  dispatcher, which never reads a spec or plan, does not.
