---
description: Author a factory spec through guided discussion, then create the ticket triple — GitHub issue, ticket branch and thoughts/factory/GH-<n>/spec.md — over REST under your own login, and offer to release it with tsf:queued.
argument-hint: "[what to build]"
disable-model-invocation: true
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-read.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh":*)
---

# Author a Factory Spec

You are tasked with the factory's one deliberately interactive step: working out
a spec with the user — what should be built and why — until it meets the
sufficiency minimum, then creating the **ticket triple** the factory works from:
a GitHub issue, a ticket branch, and `thoughts/factory/GH-<n>/spec.md` committed
on that branch.

Everything is created over REST, under the user's own GitHub login —
deliberately: issues and specs are the human's. No checkout is touched: not this
working copy, and not the factory's clone, which may be mid-cycle.

## Project context

Read `${CLAUDE_PROJECT_DIR}/.claude/tsf/config.md` **now, in full**. If it is
missing, tell the user to run `/tsf:init` first and stop. Take from it: the
repository (`owner/repo`), the base branch, the branch pattern, the responders,
the project profile (to phrase anchors in the project's terms) and the commit
convention.

### AskUserQuestion dialog guidelines

When asking the user something, follow these rules:

- Use the AskUserQuestion tool when a small set of concrete options exists
  (2–4); ask in plain prose only when the answer is genuinely free-form.
- Print a short intro paragraph (1–3 plain sentences) as a normal message
  before invoking the tool — it carries all context. The question text contains
  only the question itself: no background, no nested parentheticals.
- Put the recommended or detected option first, append " (Recommended)" to its
  label, and give the reasoning (e.g. how it was detected) in that option's
  description.
- At most 4 questions per call — batch related questions into one call. Never
  offer an "Other" or "custom" option: the tool adds one automatically.
- Headers ≤12 characters; labels 1–5 words; descriptions 1–2 plain sentences on
  what choosing the option means. Plain text only — markdown is not rendered
  inside the dialog.
- Use multiSelect only when choices are not mutually exclusive, and phrase the
  question accordingly.

---

## Initial Response

With an argument, treat it as the starting description and begin authoring.
Without one, respond with:

```
Tell me what you want the factory to build or fix — a sentence or a rough idea
dump is enough. I'll work it into a spec with you, then create the GitHub issue,
the ticket branch and the spec file, and offer to release it to the factory.

Tip: mention where in the system it lives (a screen, command, endpoint, error
message or file) — that anchor is what research starts from.
```

Then wait for the user's input.

## Authoring

1. Read `${CLAUDE_PLUGIN_ROOT}/references/templates/spec.md` **now — in full,
   even if you read it earlier in this session**. It defines the sufficiency
   minimum and the skeleton.
2. Iterate WHAT and WHY with the user. Push for the minimum — scope you can draw
   a line around, an outcome someone could observe, at least one concrete anchor
   into the system. Ask in focused batches; look into the codebase yourself only
   to confirm an anchor or to ask a sharper question, never to design the change.
3. Present, for review:
   - the **issue title** — short, in the user's terms;
   - the **issue summary** — two to four plain sentences for humans skimming the
     backlog (the spec carries the detail);
   - the **spec**, filled from the template, with `## Open questions` "None." and
     `## Decisions` "None yet." unless the discussion settled something worth
     recording.
4. Refine until the user explicitly confirms all three. Write nothing before
   that.

## Create the triple

Write the confirmed issue summary and spec to two files in your scratchpad
directory (never inside the project). Then run each step and check its
`result:` line. Anything other than the expected result → show the `detail:`
line, list what already exists (issue URL, branch), and stop; never retry by
hand and never work around a failed step.

1. **Issue:**
   `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh" issue-create --repo <owner/repo> --as ambient --title "<title>" --body-file <summary file>`
   → expect `created`; take `number:` as `n`. The canonical ticket ID is
   `GH-<n>`. Replace `[n]` in the spec's heading with the number and rewrite the
   spec file.
2. **Branch** — the name is the branch pattern with `<n>` replaced (e.g.
   `gh-<n>` → `gh-42`):
   `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh" ref-create --repo <owner/repo> --as ambient --branch <branch> --from <base branch>`
   → expect `created`. `exists` means a branch of that name was already there:
   stop and tell the user — never commit onto a branch you did not create.
3. **Spec commit:**
   `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh" contents-put --repo <owner/repo> --as ambient --branch <branch> --path thoughts/factory/GH-<n>/spec.md --file <spec file> --message "<message>"`
   with the message in the project's commit convention and scope `GH-<n>` (e.g.
   `docs(GH-<n>): add spec`) → expect `created`.
4. **Marker block** — appended to the issue body now that the branch exists (its
   name derives from the issue number):
   `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh" marker --repo <owner/repo> --as ambient --issue <n> --ticket GH-<n> --branch <branch>`
   → expect `ok`.
5. **Release** — ask with the AskUserQuestion tool, following the
   AskUserQuestion dialog guidelines (above). Use this copy verbatim — print the
   intro, then ask:

   Intro (message above the dialog):

   ```
   The ticket exists: issue, branch and spec. Releasing it adds the tsf:queued
   label, and the factory picks it up on its next cycle, starting with research.
   ```

   Question: "Release the ticket to the factory now?" — header: "Release",
   options:

   1. **Release now (Recommended)** — Labels the issue tsf:queued; the factory
      takes it from there.
   2. **Keep unreleased** — The issue stays invisible to the factory until you add
      tsf:queued yourself.

   On **Release now**:
   `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh" labels --repo <owner/repo> --as ambient --issue <n> --set tsf:queued`
   → expect `ok`.

## Report

```
Ticket GH-<n> created:
- Issue:  <issue url>
- Branch: <branch> (from <base branch>)
- Spec:   https://github.com/<owner/repo>/blob/<branch>/thoughts/factory/GH-<n>/spec.md
[Released with tsf:queued — the factory picks it up on its next cycle.
 | Not released — add the tsf:queued label when you want the factory to start.]
```

## Important Rules

- **Your own login, deliberately** — every call uses `--as ambient`; the
  factory's identity is never used here.
- **No checkout is touched** — no `git checkout`, no local branch, no local
  commit, no push. `git status` in this working copy is unchanged afterwards.
- **REST only, through the plugin's scripts** — never `gh issue`, `gh label` or
  any other `gh` porcelain, and never a raw `gh api` call.
- **Nothing is created before the user confirms** the title, summary and spec.
- **The issue body is the human summary**; the spec lives in the repository. The
  marker block appended below the summary is the only later change to the body.
- Temporary files go in your scratchpad directory, never in the project.
