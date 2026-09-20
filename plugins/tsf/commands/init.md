---
description: Set up tsf in this project — analyze it, agree the GitHub coordinates, factory identity, responders and environment contract, write .claude/tsf/config.md, create the tsf:* labels, check the factory credential, and offer the allowlist and the comment-pickup workflow.
argument-hint: ""
disable-model-invocation: true
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-read.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh":*), Bash(git remote:*), Bash(git symbolic-ref:*), Bash(git log:*), Bash(git branch:*)
---

# Initialize tsf

You are tasked with setting up **tsf**, the software factory, in the current
project: analyzing it, agreeing its factory configuration with the user, writing
`.claude/tsf/config.md`, and preparing GitHub and the project for an unattended
factory runner.

**Do not write any files until the user confirms** (Phase 4). Analyze first,
propose, discuss, then write. This command runs in the human's own working copy,
under the human's own GitHub login — deliberately: labels and setup are the
human's. The factory itself later runs in a separate, dedicated checkout.

## Project context

- Read `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` for the installed tsf
  version (its `version` field).
- If `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` exists, read it — **as a seed
  only** for the project profile (stack, commands, conventions, commit
  convention). tsf never requires it and never reads it at runtime; a project is
  on tce or on tsf for its ticket work, not both.
- If `${CLAUDE_PROJECT_DIR}/.claude/tsf/config.md` exists, read it now and follow
  "Idempotency" below.

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

## What gets created

```
.claude/tsf/config.md                     # the only tsf project file: profile, GitHub, contract, constants
[contract script skeletons]               # only those you confirm, at the paths you choose
.github/workflows/tsf-comment-pickup.yml  # only if you confirm the comment-pickup workflow
.claude/settings.json  permissions.allow  # only the entries you approve (appended, nothing else touched)
```

On GitHub: the fourteen `tsf:*` labels (created, or updated in place).

Everything under `.claude/` and `.github/` is meant to be **committed**: the
factory's own checkout must contain the same config, scripts and allowlist.

## Phase 0: Preflight — check dependencies

```bash
command -v git >/dev/null && echo "git: ok" || echo "git: MISSING (required)"
command -v gh  >/dev/null && echo "gh: ok"  || echo "gh: MISSING (required — every GitHub call is gh api over REST)"
command -v jq  >/dev/null && echo "jq: ok"  || echo "jq: MISSING (required — the tsf scripts parse GitHub JSON with it)"
```

- All three are required by tsf's scripts, here and in the factory's checkout.
  A missing one breaks label creation and every factory cycle; analysis and
  proposal below still work. Tell the user how to install it, and continue —
  the write phase stops at the first script call that needs it.

## Phase 1: Analyze the project

Investigate the repository yourself (Glob/Grep/Read/Bash). Gather, each as a
suggestion the user confirms:

1. **Project profile** — stack, build/test/lint commands, code conventions,
   commit convention. When the tce profile was read above, take these from it
   and check them against the repository; otherwise derive them from manifests
   and lockfiles (`package.json`, `composer.json`, `go.mod`, `pyproject.toml`,
   `Cargo.toml`, …), their scripts, a `Makefile`/`Taskfile`, CI config under
   `.github/workflows/`, and an existing `CLAUDE.md`/`README.md`. Commit
   convention: scan `git log --format=%s -n 30`; a majority matching
   `^\w+(\(.+\))?: ` → Conventional Commits with the scope `GH-<n>`; otherwise
   describe the style you see.
2. **GitHub coordinates** — `git remote get-url origin`; parse `owner/repo` from
   `https://github.com/owner/repo(.git)` or `git@github.com:owner/repo(.git)`.
   A non-GitHub or missing remote → tsf cannot run here; say so and stop after
   the proposal.
3. **Base branch** — `git symbolic-ref --short refs/remotes/origin/HEAD` (strip
   `origin/`); if absent, `git branch --show-current`.
4. **Branch pattern** — look for ticket branches in `git branch -r`: names that
   contain an issue number, e.g. `origin/gh-12` → `gh-<n>`,
   `origin/issue-12-login` → note the slug and propose `issue-<n>` (tsf does not
   use slugs). Also look for a commit-msg hook or CI rule keyed on branch names.
   Nothing found → propose `gh-<n>`.
5. **Your login** — `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-read.sh" whoami --repo
   <owner/repo> --as ambient`. It is the default responder (fall back to the
   repository owner when the call fails).
6. **Contract scripts** — for each of `prepare`, `env_up`, `env_reset`, `verify`,
   `env_check`, look for an existing script: `scripts/<name>.sh`,
   `.claude/tsf/scripts/<name>.sh`, `bin/<name>`, `scripts/<name>`. Record found
   paths and whether each is executable.
7. **What the missing scripts must do here** — from items 1 and 6: the git
   sequence `prepare` needs; the services `env_up` would start (compose files,
   devenv, service definitions) and whether ports are fixed; what a clean
   baseline means for `env_reset` (migrations, seeds — or a test suite that
   builds its own state); the exact command CI runs, for `verify`.
8. **Existing tsf setup** — `.claude/tsf/config.md` (→ Idempotency) and
   `.github/workflows/tsf-comment-pickup.yml`.

## Phase 2: Propose

Present the findings. Do **not** write anything yet.

```
Here's what I found and what I propose for the tsf setup:

**Project profile:** [stack] · test: [cmd] · lint: [cmd] · build: [cmd] · commits: [convention]
**GitHub:** [owner/repo], base branch [branch], ticket branches [pattern]
**Responders (default):** [your login]
**Environment contract:**
- prepare:   [found at path | missing — must: …]
- env_up:    [found at path | missing — must: …]
- env_reset: [found at path | missing — must: …]
- verify:    [found at path | missing — must run: …]
- env_check: [found at path | not registered (optional)]

**The factory runner needs, in its own checkout:** CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1
exported before starting Claude Code — without it agents run in the background and
a cycle cannot wait for them; /tsf:cycle refuses to run without it.
```

Then ask the free-form questions in plain prose, in one message: the **factory
login** (the second GitHub account that will author every factory comment,
commit and pull request — it must be a write collaborator, and it must not be
you, because GitHub refuses a review of one's own pull request), and whether
the **responders** — the logins whose issue replies count as the human's answer
— are just the proposed login or more.

Then ask about the **factory credential and runner mode** with the
AskUserQuestion tool, following the AskUserQuestion dialog guidelines (above).
Use this copy verbatim — print the intro, then ask:

Intro (message above the dialog):

```
The factory acts as its own GitHub account, never yours: every REST call and
every push resolves the factory's token explicitly, per call. Choose where
that token comes from, how the factory verifies its work, and how it notices
your replies on parked issues.
```

Question: "Where does the factory's token come from?" — header: "Credential",
options:

1. **GH_TOKEN in the environment (Recommended)** — You export the factory
   account's token as GH_TOKEN in the shell that starts the factory's session.
2. **Credential proxy** — A proxy or sandbox injects the factory token by
   repository URL; tsf passes no token itself.

Question: "How is a change verified?" — header: "Verify mode", options:

1. **Locally (Recommended)** — The verify script runs in the factory's checkout;
   CI on the pull request confirms it.
2. **CI only** — The local environment cannot run the suite; the CI result on
   the pull request is the verification.

Question: "How should the factory notice your replies?" — header: "Pickup",
options:

1. **Pickup workflow (Recommended)** — A small GitHub workflow swaps the label
   when you reply; it only works once merged to the default branch.
2. **Polling** — Each cycle reads the comments of parked issues, one REST call
   per parked issue.

When Phase 1 found signs of a credential proxy (a sandbox profile, proxy
configuration in the repository docs), move **Credential proxy** to position 1
with " (Recommended)" and put the detection in its description. When no `verify`
script and no runnable suite were found, recommend **CI only** instead.

Then ask about the **contract scripts** — only for commands Phase 1 did not find
— in one AskUserQuestion call. Use this copy verbatim; print the intro:

```
The factory never runs a destructive or environment-specific command line
itself: it runs your project's own scripts for them. For each script this
project does not have yet, choose where it comes from. Init cannot finish
while a mandatory one is missing.
```

For each missing command, ask: "Where does the [name] script come from?" —
header: "[name]", options:

1. **Create a skeleton (Recommended)** — Copies a commented starting point to
   .claude/tsf/scripts/[name].sh, which you then adapt.
2. **I'll provide it later** — Init writes the config but stops before
   finishing; re-run it once the script exists.

For a found script, use its path without asking. For `env_check` (optional),
ask only if the user wants one, with options **Not registered (Recommended)** —
"The factory skips the health probe." — and **Create a skeleton**. More than four
questions → split into two calls. A path of the user's own arrives via the
automatic "Other" option.

## Phase 3: Refine

Iterate until the user confirms the whole configuration. For every mandatory
command that is missing, explain from the Phase 1 analysis what its script has
to do for **this** project:

- **prepare** `<branch> <base-branch>` — the git sequence: discard local changes
  and untracked files (ignored files stay), fetch, check out the branch, create
  it from the base branch when it does not exist on the remote, prune branches
  deleted upstream. This is the one sanctioned hard reset; it only ever runs in
  the factory's dedicated checkout.
- **env_up** — the services to start and their start command; idempotent;
  per-checkout ports if the factory's checkout shares the machine with yours.
- **env_reset** — what a clean baseline means here, including the case where the
  suite manages its own state (then the script only says so and exits 0).
- **verify** — the exact command CI runs.

Ask for explicit confirmation of the proposal, including the foreground
requirement above.

## Phase 4: Write (only after explicit confirmation)

Every step reports its outcome. A script's `result:` other than the expected
ones → show its `detail:` line and stop, listing what is already done; a re-run
continues from there (see Idempotency).

1. **Config.** `templates/tsf/config.md` is the single source of truth for its
   structure — copy it, then fill it; never reproduce it from memory:

   ```bash
   mkdir -p "${CLAUDE_PROJECT_DIR}/.claude/tsf"
   cp "${CLAUDE_PLUGIN_ROOT}/templates/tsf/config.md" "${CLAUDE_PROJECT_DIR}/.claude/tsf/config.md"
   ```

   Read the copied file, then replace every placeholder with the agreed values
   and drop the bracketed guidance. Fill line 1's `tsf-config-version` with the
   installed plugin version. For **Credential source** `env`, record where the
   token comes from in the user's words (a password manager entry, a file
   outside the repository) — never the token itself.

2. **Skeletons** — for each confirmed skeleton:

   ```bash
   mkdir -p "${CLAUDE_PROJECT_DIR}/.claude/tsf/scripts"
   cp "${CLAUDE_PLUGIN_ROOT}/templates/tsf/scripts/<name>.sh" "${CLAUDE_PROJECT_DIR}/.claude/tsf/scripts/<name>.sh"
   chmod +x "${CLAUDE_PROJECT_DIR}/.claude/tsf/scripts/<name>.sh"
   ```

   Tell the user which skeletons still need project-specific content (`verify`'s
   skeleton fails on purpose until edited).

3. **Contract check:**

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh" --prepare <path> --env-up <path> --env-reset <path> --verify <path> [--env-check <path>]
   ```

   `result: incomplete` → for each failing item, state what its script must do
   (from Phase 3), what is still needed (create it, or `chmod +x` it), and how to
   finish: "re-run `/tsf:init` — the config is kept and setup continues from the
   checks". **Stop here without declaring init finished.**

4. **Labels** — for each label, run
   `"${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh" label-create --repo <owner/repo> --as ambient --name <label> --color <hex> --description "<meaning>"`:

   | Label | Colour | Description |
   |---|---|---|
   | `tsf:queued` | `d4d4d4` | Released by the human; the factory determines the first step |
   | `tsf:research` | `d4d4d4` | Spec sufficient; research is next |
   | `tsf:plan` | `d4d4d4` | Research done; planning is next |
   | `tsf:implement` | `d4d4d4` | Plan approved; implementation is next |
   | `tsf:verify` | `d4d4d4` | PR open; local verification, CI and the gates run |
   | `tsf:dossier` | `d4d4d4` | All gates green; dossier is next |
   | `tsf:rework` | `d4d4d4` | Changes requested; implementation addresses the review |
   | `tsf:landing` | `d4d4d4` | Approved; sync, integration gate and merge are next |
   | `tsf:answered` | `d4d4d4` | Human replied to questions or to the plan summary; distillation is next |
   | `tsf:needs-answer` | `d73a4a` | Parked: numbered questions posted |
   | `tsf:needs-plan-approval` | `d73a4a` | Plan pushed and summarized; awaiting the human's reply |
   | `tsf:needs-review` | `d73a4a` | CI green, dossier posted on the PR; awaiting review |
   | `tsf:needs-human` | `d73a4a` | Blocked: attempts exhausted, environment broken, logic conflict, state mismatch |
   | `tsf:priority` | `fbca04` | Pick before other tickets |

   Report `created`/`updated` per label in one short list. Any `rejected`,
   `denied` or `failed` → stop with the detail (a `404` usually means your login
   cannot manage labels on the repository).

5. **Factory credential check.** The check must use the factory's token from the
   configured source — never this session's login, which is yours:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh" --prepare <path> --env-up <path> --env-reset <path> --verify <path> [--env-check <path>] --identity --credential <env|proxy> --factory-login <login> --responders <a,b>
   ```

   For source `env`, this session normally has no factory `GH_TOKEN` (it is your
   working copy). Then print that exact command prefixed with
   `GH_TOKEN="$(<however you read the factory token>)"` and suggest the user run
   it with the `!` prefix, so the token never appears in the conversation. Act on
   the `identity:` line the user's run (or yours) reports:

   - `ok` → continue.
   - `mismatch` → **stop**: the token authenticates as another account; fix the
     token or the factory login, then re-run.
   - `responder` → **stop**: the factory login is also a responder — the human
     would be reviewing their own pull requests.
   - `unavailable` → the user may defer: record it under "still needed" and
     continue; `/tsf:cycle` runs the same check at the start of every cycle and
     writes nothing until it passes.

6. **Allowlist** — the factory runs unattended, so the tools it needs must not
   prompt. Compute the entries:
   - each registered contract script: `Bash(<path>:*)`
   - the workers' local git: `Bash(git add:*)`, `Bash(git commit:*)`,
     `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(git show:*)`,
     `Bash(git status:*)`, `Bash(git rev-parse:*)`, `Bash(git branch:*)`
   - the factory's artifact edits: `Edit(thoughts/factory/**)`
   - the profile's build, test and lint commands: `Bash(<command>:*)`
   - the plugin's own files: `Read(~/.claude/plugins/**)`. The factory's agents
     read tsf's reference templates at the point of use, and those live outside
     the project directory — without this, every unattended cycle stops on a
     permission request the agent cannot answer. (Only `/tsf:cycle`'s own reads
     are covered by its frontmatter; an agent's are not. If tsf is loaded from
     somewhere else — `--plugin-dir` during development — grant that directory
     instead.)

   **Never** `git push` and never `gh` — pushes and GitHub calls go through the
   plugin's own scripts, which `/tsf:cycle` grants itself. Show the exact entries
   that would be appended to `${CLAUDE_PROJECT_DIR}/.claude/settings.json`
   `permissions.allow`, then ask. Use this copy verbatim — print the intro, then
   ask:

   Intro (message above the dialog):

   ```
   These permission entries let the unattended factory run its scripts, commit
   and run your project's commands without stopping on a prompt. They are
   appended to .claude/settings.json; nothing else in that file changes.
   ```

   Question: "Append these entries to .claude/settings.json?" — header:
   "Allowlist", options:

   1. **Append them (Recommended)** — The factory's checkout picks them up once
      you commit the file.
   2. **Skip** — Every unattended cycle will stop at the first prompt until you
      allow these tools yourself.

   On approval, edit surgically: if the file does not exist, create it with only
   `{"permissions": {"allow": [...]}}`; otherwise append the missing entries to
   the existing `permissions.allow` array (creating the array if needed), no
   duplicates, and leave every other key and entry byte-identical.

7. **Comment-pickup workflow** (only when chosen):

   ```bash
   mkdir -p "${CLAUDE_PROJECT_DIR}/.github/workflows"
   cp "${CLAUDE_PLUGIN_ROOT}/templates/github/tsf-comment-pickup.yml" "${CLAUDE_PROJECT_DIR}/.github/workflows/tsf-comment-pickup.yml"
   ```

   Replace `__TSF_RESPONDERS_JSON__` with the responders as a JSON array, e.g.
   `["octocat","hubot"]`. Tell the user: it fires only once the file is on the
   default branch; pushing it needs the `workflow` token scope; until it is
   merged, replies are not picked up unless `Comment pickup` is `polling`.

8. **Checklists** — print both; they are manual because the settings are
   admin-only or live outside this checkout:

   ```
   Repository ruleset for the base branch (Settings → Rules):
   [ ] Pull request required, with 1 approving review
   [ ] Required status check, with "require branches to be up to date"
   [ ] No bypass for the factory account; it stays a plain write collaborator
   [ ] "Dismiss stale approvals" and "require approval of the most recent push" off
   [ ] Automatically delete head branches (Settings → General)
   [ ] The CI workflow providing the required check must NOT path-filter
       thoughts/** — every journal commit touches only thoughts/, and a
       filtered-out required check blocks the merge

   The factory's checkout:
   [ ] A second, dedicated clone of the repository, used by nothing else
   [ ] If you use a sandbox: its filesystem grant covers that clone's path
   [ ] env_up allocates per-checkout ports if the clone shares a machine with yours
   [ ] In the shell that starts the factory:
         export CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1
         export GH_TOKEN=...        (credential source env only)
   [ ] Start claude in the clone, run /tsf:cycle once, then /loop /tsf:cycle
   ```

9. **Hand off** — list what was written and what is still needed, then:

   ```
   Commit .claude/tsf/, the contract scripts, .claude/settings.json and the
   workflow, and get them onto the base branch — the factory's clone reads them
   from there. Then create the first ticket with /tsf:spec.
   ```

   Do **not** commit automatically.

## Idempotency

If `.claude/tsf/config.md` exists, never clobber it. Show what differs from your
fresh analysis and ask which values to update; apply agreed amendments with
`Edit`.

Compare its line-1 `tsf-config-version` marker with the installed version:

- **Same version** — report "tsf config is already up to date (v[X.Y.Z])", then
  offer to run the setup steps again without rewriting the config: Phase 4 steps
  2–8 (skeletons for still-missing scripts, contract check, labels, credential
  check, allowlist, workflow, checklists). This is also how an init that stopped
  at the contract check is finished.
- **Older or missing** — the config was written by an older tsf (or predates
  markers): walk through the upgrade list below, ask before writing, then update
  the marker. Today's list:
  - `0.1.0` — initial release; nothing to migrate.
  - `0.2.0` — nothing to migrate; `verify_fix_bound` and `gate_fix_bound`
    became live, so a project that edited them now sees them take effect.
  - `1.0.0` — `## Constants` gains **`landing_attempt_bound`** (default 3),
    which bounds the landing's restarts. A config without the line is upgraded
    by appending it; until then the landing falls back to 3.

**When a later tsf version changes what `config.md` must contain, extend this
list in the same commit.**

## Notes

- This command's one edit to `.claude/settings.json` is the approval-gated
  append of `permissions.allow` entries in Phase 4 step 6; it never changes
  anything else in that file.
- It never touches `thoughts/`, never pushes, and never commits.
- It never configures the factory's clone path: the factory's session is opened
  in its clone, so the project directory is the clone.
