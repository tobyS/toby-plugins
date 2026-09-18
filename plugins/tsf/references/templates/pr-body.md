<!--
Runtime reference for the tsf software factory. Read at the point of use —
always in full, even if already read earlier in the session — by /tsf:cycle
before it opens a pull request, and by the tsf:dossier agent when it validates
the pull request's title and body. Never copied into consuming projects.

Changes to this file are command-contract changes: the title is the squash
commit's subject (DESIGN.md §9.3) and the closing keyword is what closes the
issue on merge, so changing either requires updating
plugins/tsf/references/cycle-write-phase.md and plugins/tsf/agents/dossier.md in
the same commit.

Contents:
1. The title
2. The body skeleton
3. Rules
-->

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
- No angle brackets and no fenced code blocks: the body travels through the
  dispatcher as text.
