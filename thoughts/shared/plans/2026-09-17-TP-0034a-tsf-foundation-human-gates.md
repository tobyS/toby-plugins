# TP-0034a: tsf slice 1 — foundation, init, spec, and the cycle up to plan approval — Implementation Plan

## Overview

Build the first usable slice of the tsf plugin (Toby Software Factory) as a
new marketplace plugin at version `0.1.0`: the scaffold, the shipped scripts
(scan, one REST write helper, push, preflight), the project templates
(`config.md`, contract-script skeletons, the comment-pickup workflow), the
reference templates, the three worker agents (`tsf:triage`, `tsf:research`,
`tsf:plan`), the three commands (`/tsf:init`, `/tsf:spec`, `/tsf:cycle` for
dispatch rows 1–4 and 13), and the repo's governance sections. After this
slice a consumer can release a ticket and get research and a plan summary to
approve on GitHub, driven by `/loop /tsf:cycle`.

The binding specification is `plugins/tsf/DESIGN.md` v1.4. This plan bakes in
the seven planning decisions taken with the user on 2026-09-16/17 (see
"Implementation Approach") and surfaces every deviation from DESIGN.md it
needs, per the epic's rule that deviations are surfaced, never silently made.

## Current State Analysis

- `plugins/tsf/` contains only `DESIGN.md`. The plugin is invisible to the
  marketplace until `plugins/tsf/.claude-plugin/plugin.json` and an entry in
  `.claude-plugin/marketplace.json` exist (research §1).
- The house style for every artifact type is fully determined by tce, tmt and
  tle (research Summary): the `report()` stdout contract of
  `plugins/tce/scripts/baseline.sh:46-51` / `branch.sh:81-86`; the four-part
  verbatim dialog frame of `plugins/tce/commands/init.md:201-229`; the
  one-iteration-per-turn dispatcher of `plugins/tle/commands/run.md:10-18`
  with invariants placed *before* `## Project context`; the three-part
  constraint envelope of `plugins/tce/agents/plan-compliance-checker.md:28-35,73-99`;
  reference-file preambles and the point-of-use read phrasing of
  `plugins/tce/commands/research.md:303`.
- No script in the repo calls `gh` or any GitHub API; tsf's `scripts/` is the
  repo's first shell-level GitHub integration (research §6).
- The `### AskUserQuestion dialog guidelines` block exists in ten
  byte-identical copies; `/tsf:init` and `/tsf:spec` add two (research Impact
  Analysis).
- Four docs surfaces enumerate plugins: `README.md:19-23` (deferred to
  TP-0034c), `CONTRIBUTING.md:32-57`, `CLAUDE.md` (layout block + rule
  sections), `.claude/tce/profile.md:27-48`.

### Platform facts the plan rests on (research §7–§9)

- The scan must be `GET /repos/{o}/{r}/issues?state=open&per_page=100` with
  client-side `jq` filtering; `/search/issues` is blocked by the first
  consumer's proxy and has no freshness guarantee. Pull requests appear in the
  same listing and are discriminated by the `pull_request` key.
- No GitHub write endpoint has a concurrency guard; every write is
  last-write-wins. The label replace is `PUT /repos/{o}/{r}/issues/{n}/labels`
  (DESIGN.md calls it "the full-set PATCH").
- Two "forbidden" shapes must not be conflated or retried: GitHub's `404` for
  missing permissions, and the proxy's bare `{"error":"Forbidden"}` with no
  GitHub response headers. Only a transport error is retried.
- `GH_TOKEN` in the environment takes precedence over `gh`'s keyring login;
  `gh api` has no `--token` flag.
- A skill's `allowed-tools` is never gated by workspace trust and is
  re-established on every `/loop` turn; `${CLAUDE_PLUGIN_ROOT}` inside it is
  documented. A project's `permissions.allow` applies once the trust dialog
  has been accepted, which is the case for the interactive `/loop` runner.
- Auto-compaction keeps the first 5,000 tokens of each invoked skill body
  (25,000 combined, most-recent-first); `cycle.md` must stay under that and
  push detail into point-of-use reference files.
- In an interactive session subagents run in the background by default and
  Claude cannot ask for the foreground; `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`
  forces foreground everywhere.
- `issue_comment` workflows fire only from the default branch, need
  `permissions: issues: write`, and responder logins must match exactly.
- Subagents return a single final text; since v2.1.210 the output may be
  prefixed with a `[harness: …]` marker and have `<` escaped inside
  instruction-shaped text.

## Desired End State

`/plugin install tsf@toby-plugins` installs a plugin whose `/tsf:init` sets a
project up (config, contract check, labels, credential check, allowlist,
pickup workflow, checklists), whose `/tsf:spec` creates the ticket triple over
REST, and whose `/tsf:cycle` advances one ticket one step through triage,
research and plan, parks it with batched questions or the plan summary, picks
the responder's reply up (workflow or polling), and stops at `tsf:implement`
reporting later-slice rows as not implemented. Every GitHub write goes through
one shipped helper. `claude plugin validate` passes for the marketplace and
the plugin. CLAUDE.md records the same-commit spans this slice creates.

Verification: the automated criteria of each phase (validate, `jq`/`grep`
assertions, script smoke tests against a scratch repository), plus the
end-to-end smoke test in "Testing Strategy".

### Key Discoveries:

- Marketplace entries use exactly four keys in order — `name`, `source`,
  `description`, `version` — and `claude plugin validate` accepts a
  manifest-only plugin (research §1).
- Command frontmatter key order is `description` → `argument-hint` → `model`
  → `disable-model-invocation` → `allowed-tools`; script grants are written
  `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/x.sh":*)` (`plugins/tce/commands/research.md:4`).
- The flag classification is fixed: `init` and `spec` flagged, `cycle`
  unflagged because `/loop` fires it as a prompt (DESIGN.md §12, research §2).
- Both `branch.sh` and `stage.sh` take everything as arguments and never read
  project config (CLAUDE.md, TP-0033) — the model for tsf's scripts.
- `AskUserQuestion` is stripped from every subagent; the worker agents can
  never ask the user anything (research §9).
- `LS` is not a tool; agent `tools:` is a single-line comma-separated scalar
  (research §4).
- tle's `model:` pins are aliases, never IDs; `claude plugin validate` does
  not check `model:` values, so a pin is proven on a real dispatch (CLAUDE.md,
  TP-0029).

## What We're NOT Doing

- Implementation, verification, the four gates, fix/rework modes, dossier,
  review handling (TP-0034b); landing, integration gate, merge, root README
  catalog, the `tsf--v1.0.0` tag (TP-0034c). Dispatch rows 5–12 are reported
  as "not implemented in this slice", never guessed.
- Any DESIGN.md §14 non-goal; the `claude -p` runner; any change to tce or
  tmt; any dependency between tsf and tce.
- Editing DESIGN.md. Wording reconciliations this plan finds (PUT vs "PATCH",
  prepare-before-decide) are recorded here and in script/command comments,
  not applied to the design document.
- Dogfooding tsf in this repo (it targets GitHub-issue projects with a
  factory clone; this repo uses tmt tickets).
- The first consumer project's own changes (its contract scripts, ruleset,
  `factory-design.md`).

## Implementation Approach

Bottom-up, one validatable layer per phase (the tle precedent): manifest and
marketplace entry first so `claude plugin validate` covers everything after;
then the scripts (pure shell, testable against a scratch repository); then the
project and reference templates the agents and commands read; then the agents;
then the three commands, `cycle` last because it consumes everything; then the
docs and CLAUDE.md rules.

**Planning decisions (agreed 2026-09-16/17), applied throughout:**

1. **Foreground dispatch** is a runner requirement: `/tsf:cycle` requires
   `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` in its environment and ends the
   cycle with a report when it is absent (no smoke-test spike). `/tsf:init`
   documents it in the factory-clone checklist.
2. **A research-parked answer is processed by `tsf:research`**: the parking
   step's agent resumes with the reply, folds it into `spec.md`, re-validates
   `research.md`, and returns `tsf:plan` or a second question batch. The
   resume rule is therefore uniform in this slice: *the step that parked
   resumes with the reply* (triage → triage, research → research, plan gate →
   plan).
3. **Workers stay inline**: `tools:` allowlist without `Agent`
   (`Read, Write, Edit, Grep, Glob, Bash`), never a denylist.
4. **Model pins**: `triage` and `research` `sonnet`, `plan` `opus` — aliases,
   explicit, never `inherit` (TP-0029 rule).
5. **`config.md` stays prose-only**; the dispatcher reads it and passes every
   value to the scripts as arguments. No machine-readable companion.
6. **`/tsf:init` writes the allowlist** into `.claude/settings.json`
   `permissions.allow` on explicit approval, surgically — the repo's second
   sanctioned `settings.json` edit (documented in CLAUDE.md, Phase 9).
7. **One REST write helper with an identity mode** (`--as factory|ambient`);
   `/tsf:spec` and `/tsf:init` use it in ambient mode. The helper retries a
   transport error once and reports; parking is the cycle's action on the
   `result:` line, interactive commands show the failure and stop.

**Deviations from DESIGN.md surfaced by this plan** (recorded, not applied to
the design document):

- **Prepare precedes decide** for the picked ticket (DESIGN.md §5.1 lists
  Decide before Prepare). The derived state is the journal's last `Next step`
  (§3.3), which lives on the ticket branch, so the branch must be checked out
  before the row can be decided. The pick itself uses scan data only.
- **The label replace is `PUT …/issues/{n}/labels`**; §3.4 and §10 say
  "full-set PATCH". The helper's header comment maps the two.
- **The `prepare` contract command takes the base branch as a second
  argument** (`prepare <branch> <base-branch>`) so a project script can create
  a missing branch without reading tsf config.
- **The identity check runs at the start of every cycle** (one `GET /user`),
  not only in `/tsf:init`, so a runner started with the wrong credential
  stops before writing anything.
- **The one-line distillation confirmation is the first line of the step's
  single comment**, not a second comment (§10: exactly one comment per step).
- **Triage and research questions are also recorded in `spec.md`'s
  "Open questions" section** (and the plan's in `plan.md`) so the resuming
  agent can pair the reply with the questions without reading GitHub.
- **The result block is three fenced blocks** with distinct info strings
  (`tsf-result`, `tsf-comment`, `tsf-journal`) and no angle brackets, robust
  to the harness marker and `<` escaping.

**Precondition (epic):** merge `tsf-design` into `main` before Phase 1 starts;
implementation commits land on `main`.

---

## Phase 1: Scaffold and registration

### Overview

Make tsf a plugin the marketplace sees, at `0.1.0`, with a README stub that
states the slice-1 scope. Nothing functional yet; every later phase is
validated by the two commands this phase makes pass.

### Changes Required:

#### 1. Plugin manifest

**File**: `plugins/tsf/.claude-plugin/plugin.json` (new)
**Changes**: Mirror the key set of `plugins/tle/.claude-plugin/plugin.json`
(`name`, `version`, `description`, `author{name,email}`, `keywords[]`; no
`userConfig`).

```json
{
  "name": "tsf",
  "version": "0.1.0",
  "description": "Toby Software Factory — an agentic software factory over GitHub issues: one work step per cycle in a fresh context, async human gates on the issue, artifacts in the repo. Slice 1: init, spec, and the cycle up to plan approval.",
  "author": { "name": "<copy from tle manifest>", "email": "<copy from tle manifest>" },
  "keywords": ["factory", "github", "agents", "workflow", "autonomous"]
}
```

#### 2. Marketplace entry

**File**: `.claude-plugin/marketplace.json`
**Changes**: Append a fourth entry to `plugins[]`, four keys in order, version
mirroring the manifest:

```json
{
  "name": "tsf",
  "source": "./plugins/tsf",
  "description": "Agentic software factory over GitHub issues (slice 1: init, spec, cycle to plan approval)",
  "version": "0.1.0"
}
```

#### 3. README stub

**File**: `plugins/tsf/README.md` (new)
**Changes**: Title, one-paragraph what-it-is, a "Slice 1 (0.1.0) scope"
section listing what works (init, spec, cycle rows 1–4 and 13) and what is
reported as not implemented, a pointer to `DESIGN.md`, and an "Install"
section (`/plugin install tsf@toby-plugins`). Phase 9 completes it.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` passes (run in repo root)
- [x] `claude plugin validate ./plugins/tsf` passes
- [x] `jq -e '.plugins | length == 4' .claude-plugin/marketplace.json`
- [x] `jq -r '.plugins[] | select(.name=="tsf") | .version' .claude-plugin/marketplace.json` prints `0.1.0` and equals `jq -r .version plugins/tsf/.claude-plugin/plugin.json`
- [x] `jq -e '.plugins[] | select(.name=="tsf") | keys == ["description","name","source","version"]' .claude-plugin/marketplace.json`

#### Manual Verification:

- [ ] None.

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `c22dce8aeaab75449e766525a46622d182f0edde` (after the
  precondition: `tsf-design` fast-forwarded into `main`)
- **Commit**: `bf58f3c` feat(TP-0034a): register the tsf plugin at 0.1.0
- **Did**: `plugins/tsf/.claude-plugin/plugin.json`, fourth marketplace entry,
  README stub with the slice-1 scope; ticket → In Progress.
- **Issues**: none.
- **Verification**: ✅ validate marketplace + tsf, ✅ four jq assertions

---

## Phase 2: Shipped scripts

### Overview

The five scripts every command relies on: `lib.sh`, `preflight.sh`,
`scan.sh`, `gh-read.sh`, `gh-write.sh`, `push.sh`. All follow the house
style: `#!/bin/bash`, `set -e` only, the byte-identical `SCRIPT_DIR` +
`. "$SCRIPT_DIR/lib.sh"` bootstrap, `${VAR:-}` defaults, a `report()` of fixed
`key: value` lines then `exit 0` (only usage errors exit 1), `printf '%s\n'`
for contract lines, `echo "Error: …" >&2` for errors. **No script reads
`config.md`**; every value arrives as an argument (decision 5, the `branch.sh`
division of labour). No `gh` porcelain anywhere: only `gh api`.

#### Shared conventions (all scripts)

- Identity flags: `--as factory|ambient`; with `factory`, `--credential
  env|proxy` is required.
  - `factory` + `env`: `GH_TOKEN` must be non-empty in the environment,
    otherwise `result: no-credential`; `gh api` then uses it (precedence over
    the keyring).
  - `factory` + `proxy`: the environment is left untouched (the proxy injects
    by URL; a phantom `GH_TOKEN` may be present — never assert on it).
  - `ambient`: `unset GH_TOKEN GITHUB_TOKEN` in the script's own environment
    so `gh` uses the keyring login — "the human's login, deliberately"
    (DESIGN.md §12) as a mechanical fact.
- `--repo <owner>/<repo>` on every GitHub-touching script.
- Every REST call goes through `tsf_api` in `lib.sh`, which adds
  `-H "Accept: application/vnd.github+json"` and
  `-H "X-GitHub-Api-Version: 2022-11-28"`, uses `--include` to capture the
  status line and headers, and classifies the outcome:
  - `ok` — 2xx.
  - `rejected` — an HTTP 4xx/5xx with GitHub headers present (`x-github-request-id`);
    never retried. (A `404` may mean missing permissions, DESIGN.md/research §7.)
  - `denied` — a non-2xx with **no** GitHub headers: proxy denial; never
    retried.
  - `transport` — `gh api` failed with no status line (DNS, connection,
    timeout): retried **once** by the write helper.
  - Exit code 4 from `gh` → `auth`: never retried.
  The classification is the helper's single most important piece of logic;
  its header comment states that GitHub offers no write-side concurrency
  guard and that the re-read-before-PUT is a mitigation, not a guarantee.
- Retry-then-report: after the one retry, `result: failed` with `detail:` —
  the caller decides (the cycle parks `tsf:needs-human`, interactive commands
  stop and tell the human).

### Changes Required:

#### 1. `lib.sh`

**File**: `plugins/tsf/scripts/lib.sh` (new; no `set` line, functions only)
**Changes**:

```bash
#!/bin/bash
# Shared helpers for the tsf scripts. Sourced, never executed.

tsf_project_root() { printf '%s\n' "${CLAUDE_PROJECT_DIR:-$PWD}"; }

# tsf_identity <as> <credential>   — prepare the environment for gh api / git
#   as=factory credential=env   : require GH_TOKEN (returns 1 if empty)
#   as=factory credential=proxy : leave the environment alone
#   as=ambient                  : unset GH_TOKEN GITHUB_TOKEN
tsf_identity() { …; }

# tsf_api <method> <path> [gh api args…]
#   Runs gh api with the fixed headers and --include, writes the body to
#   $TSF_API_BODY (a temp file), sets TSF_API_STATUS (HTTP status or empty),
#   TSF_API_CLASS (ok|rejected|denied|transport|auth), TSF_API_GITHUB (yes|no
#   — whether GitHub headers were present). Never exits.
tsf_api() { …; }

# tsf_normalize_id <ref>  — "#123", "123", "GH-123", an issue URL → "GH-123"
tsf_normalize_id() { …; }

# tsf_branch_for <pattern> <n> — replace <n> in the pattern, e.g. gh-<n> → gh-123
tsf_branch_for() { …; }
```

`tsf_api` must handle `--paginate` (used by the scan) by concatenating bodies;
implement pagination by following the `link` header manually if `--include`
and `--paginate` do not combine cleanly (verify at implementation; the fallback
is a `page=` loop up to a fixed cap of 10 pages).

#### 2. `preflight.sh`

**File**: `plugins/tsf/scripts/preflight.sh` (new)
**Changes**: The contract check (DESIGN.md §12) plus the two runner checks.

```
Usage: preflight.sh --prepare P --env-up P --env-reset P --verify P [--env-check P]
                    [--foreground] [--identity --repo O/R --as factory --credential C --factory-login L --responders a,b]
Output (always exit 0):
  now:        <UTC timestamp, YYYY-MM-DDTHH:MMZ>
  prepare:    ok | missing | not-executable
  env_up:     ok | missing | not-executable
  env_reset:  ok | missing | not-executable
  verify:     ok | missing | not-executable
  env_check:  ok | missing | not-executable | not-registered
  foreground: ok | missing | skipped        (ok iff CLAUDE_CODE_DISABLE_BACKGROUND_TASKS is exactly "1")
  identity:   ok | mismatch | responder | unavailable | skipped
  login:      <login GET /user returned, or ->
  result:     ok | incomplete
  detail:     <one line naming every failing item>
```

`result: ok` only when every mandatory command is `ok`, the optional one is
`ok` or `not-registered`, and every requested runner check is `ok`.
`identity: responder` means the factory login is one of the responders.
`now:` exists so the cycle needs no `date` grant.

#### 3. `scan.sh`

**File**: `plugins/tsf/scripts/scan.sh` (new)
**Changes**: Open issues carrying a `tsf:*` **state** label (not
`tsf:priority` alone), pull requests excluded, with an optional comment poll
for parked tickets.

```
Usage: scan.sh --repo O/R --as factory --credential C [--poll --responders a,b --factory-login L]
Output: one record per issue, blank-line separated, oldest first:
  issue:    123
  state:    tsf:queued            | multiple (a,b) | none
  priority: yes | no
  created:  2026-09-17T08:00:00Z
  updated:  …
  reply:    <comment id> | none | skipped     (--poll: only for tsf:needs-answer / tsf:needs-plan-approval)
  title:    <title, one line>
Trailer:
  count:    <n>
  result:   ok | failed
  detail:   …
```

- REST: `GET /repos/{o}/{r}/issues?state=open&per_page=100` paginated; jq:
  `select(.pull_request == null) | select([.labels[].name | select(startswith("tsf:") and . != "tsf:priority")] | length > 0)`.
- `state:` is the single `tsf:*` non-priority label; two or more → `multiple`
  (the cycle parks such a ticket, §3.4 "exactly one").
- `--poll`: for each `tsf:needs-answer` / `tsf:needs-plan-approval` issue,
  `GET /repos/{o}/{r}/issues/{n}/comments?per_page=100` (ascending id); the
  factory's last comment is the one whose `user.login` is the factory login
  with the highest id; `reply:` is the lowest-id comment by a responder with an
  id greater than that (none → `none`). Comments by anyone else are ignored.

#### 4. `gh-read.sh`

**File**: `plugins/tsf/scripts/gh-read.sh` (new)
**Changes**: Single-issue reads the cycle, spec and init need.

```
Usage: gh-read.sh <subcommand> --repo O/R --as … [--credential …] …
  issue   --issue N                                   → number:, title:, state:, labels:, then "body:" and the raw body verbatim
  reply   --issue N --responders a,b --factory-login L → reply: <id>|none, then "text:" and every responder comment
                                                        after the factory's last comment, each prefixed "--- <login> <created_at> ---"
  branch  --branch B                                  → exists: yes|no, sha: <sha>|-
  whoami                                              → login: <login>, result: ok|failed
```

Every subcommand ends with `result:` / `detail:` lines.

#### 5. `gh-write.sh` — the one REST write helper (DESIGN.md §11.3)

**File**: `plugins/tsf/scripts/gh-write.sh` (new)
**Changes**: Every write, read back, one retry on transport.

```
Usage: gh-write.sh <subcommand> --repo O/R --as factory|ambient [--credential env|proxy] …
  comment       --issue N --body-file F                          → POST …/issues/N/comments; 201 body is the read-back
                                                                   id: <id>, url: <html_url>
  labels        --issue N --set tsf:plan                         → GET …/issues/N (labels) immediately before;
                                                                   new set = non-tsf labels + tsf:priority if present + the one state label;
                                                                   PUT …/issues/N/labels {"labels":[…]}; GET again; verify equal
                                                                   labels: a,b,c ; result: ok | mismatch | …
  marker        --issue N --ticket GH-N --branch B [--journal] [--pr P]
                                                                 → GET …/issues/N body; replace the block between
                                                                   "<!-- tsf:links -->" and "<!-- /tsf:links -->" or append it
                                                                   (two blank lines, then the block); PATCH …/issues/N {body};
                                                                   GET again; verify block present. URLs composed by the helper:
                                                                   spec  https://github.com/O/R/blob/B/thoughts/factory/GH-N/spec.md
                                                                   branch https://github.com/O/R/tree/B
                                                                   journal https://github.com/O/R/blob/B/thoughts/factory/GH-N/journal.md (with --journal)
                                                                   PR https://github.com/O/R/pull/P (with --pr; slice 2)
  issue-create  --title T --body-file F                          → POST …/issues ; number:, url:
  label-create  --name X --color HEX --description D             → POST …/labels ; 422 already_exists → PATCH …/labels/X ; result: created|updated
  ref-create    --branch B --from BASE                           → GET …/git/ref/heads/BASE → sha; POST …/git/refs {"ref":"refs/heads/B","sha"};
                                                                   422 "Reference already exists" → result: exists; GET …/git/ref/heads/B read-back
  contents-put  --branch B --path P --file F --message M         → GET …/contents/P?ref=B (404 ok → create; 200 → carry sha);
                                                                   PUT …/contents/P {message, content: base64, branch, sha?};
                                                                   GET read-back; commit: <sha>
Common trailer: result: ok | created | updated | exists | mismatch | rejected | denied | failed | no-credential
                status: <http status or ->
                detail: <one line>
```

- The marker block is exactly:
  ```
  <!-- tsf:links -->
  **tsf:** [spec](…) · [branch](…) · [journal](…) · [PR](…)
  <!-- /tsf:links -->
  ```
  (only the links that exist). The original body above the block is never
  modified (§3.2, §10).
- `labels --set` removes every other `tsf:*` label except `tsf:priority`, so
  exactly one state label remains (§3.4). A `--clear` form (no state label)
  is slice 3's; do not add it now.
- Base64 for `contents-put`: `base64 < "$F" | tr -d '\n'` (portable across
  macOS and Linux).
- The header comment maps "full-set PATCH" (DESIGN.md §3.4, §10) to the
  `PUT` endpoint and states the no-concurrency-guard caveat.

#### 6. `push.sh`

**File**: `plugins/tsf/scripts/push.sh` (new)
**Changes**: The one push path (§12: the push resolves the factory token per
call).

```
Usage: push.sh --branch B --credential env|proxy [--remote origin]
  env:   git -c credential.helper= \
             -c credential.helper='!f() { echo username=x-access-token; echo "password=$GH_TOKEN"; }; f' \
             push "$REMOTE" "$BRANCH"
  proxy: git push "$REMOTE" "$BRANCH"
Output: result: pushed | up-to-date | no-credential | failed ; detail: <last stderr line>
```

Never `--force`, never `--force-with-lease`, never a refspec other than the
named branch. Runs in the project root (`tsf_project_root`).

#### 7. Header comments

Each script's header documents usage, the `result:` vocabulary exhaustively,
the exit-code sentence ("exit 0 for every reported outcome; only usage errors
exit 1"), and which command(s) invoke it.

### Success Criteria:

#### Automated Verification:

- [x] `bash -n` passes for all six scripts; every script except `lib.sh` is executable (`test -x`)
- [x] Every non-lib script contains the byte-identical bootstrap lines (`SCRIPT_DIR=…`, `# shellcheck source=lib.sh`, `. "$SCRIPT_DIR/lib.sh"`) — `grep -L 'shellcheck source=lib.sh' plugins/tsf/scripts/*.sh` prints only `lib.sh`
- [x] `grep -rnE 'gh (issue|pr|label|auth|run)\b' plugins/tsf/scripts/` finds nothing (no porcelain)
- [x] Usage errors: each script run with no arguments prints `Error:` to stderr and exits 1
- [x] `gh-write.sh labels --as factory --credential env` with `GH_TOKEN` unset reports `result: no-credential` and exits 0
- [x] `preflight.sh` against a scratch dir with three executable and one missing script reports the missing one and `result: incomplete`; with `--foreground` and the variable unset reports `foreground: missing`
- [x] `lib.sh`'s `tsf_normalize_id` maps `#12`, `12`, `gh-12`, `GH-12`, `https://github.com/o/r/issues/12` to `GH-12` (test by sourcing in a bash one-liner in the scratch dir)
- [x] `claude plugin validate ./plugins/tsf` still passes

#### Manual Verification:

- [ ] Against a scratch GitHub repository (see Testing Strategy) with a PAT exported as `GH_TOKEN`: `scan.sh` lists an issue labelled `tsf:queued` and omits an issue with only `tsf:priority` and an open PR; `gh-write.sh label-create` is idempotent (second run `updated`); `labels --set` on an issue carrying `bug` + `tsf:priority` + `tsf:queued` leaves `bug,tsf:priority,tsf:plan`; `marker` appends the block once and updates it in place on the second call without touching the body above; `ref-create` + `contents-put` create a branch with one commit; `push.sh --credential env` pushes a local commit; `scan.sh --poll` reports a responder reply and ignores a comment by the factory login
- [ ] A deliberate wrong token yields `result: rejected` with `status: 401` and no retry (check the helper's stderr trace once with `set -x`); an unreachable host (`GH_HOST=localhost:1`) yields one retry then `result: failed`

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `1e98dbf` feat(TP-0034a): add the tsf REST, scan, preflight and push scripts
- **Did**: `plugins/tsf/scripts/{lib,preflight,scan,gh-read,gh-write,push}.sh`,
  bash-3.2-safe (`/bin/bash` on macOS). Refinements over the plan: manual
  paging in `tsf_api_list` (`--include --paginate` interleaves header blocks);
  verbatim text (`body:`/`text:`) printed after the trailer; scan `state:` has
  no `none` (the filter makes it impossible) and a full failure vocabulary;
  `labels` also prints `previous:`; `push.sh` adds `ssh-remote` (env source
  needs https); preflight's identity flags are `--credential --factory-login
  --responders` (no `--repo`/`--as`, unused by `GET /user`).
- **Issues**: `gh` exits 1, not 4, on a bad token (401 with GitHub headers →
  `rejected`); exit 4 is only "no credential at all".
- **Verification**: ✅ 30 script checks incl. live 401/transport/200
  classification, ✅ 12 fake-`gh` checks (label set, marker append/update/
  body untouched, denied not retried, transport retried once), ✅ read-only
  live scan + branch reads, ✅ validate

---

## Phase 3: Project templates

### Overview

What `/tsf:init` copies into a consuming project: the `config.md` skeleton
(the single source of truth for its structure), the five contract-script
skeletons, and the comment-pickup workflow.

### Changes Required:

#### 1. `config.md` skeleton

**File**: `plugins/tsf/templates/tsf/config.md` (new)
**Changes**: Prose markdown in the `profile.md` skeleton style (H1, `>`
blockquote on who reads it, `[bracketed guidance]`, `[not set]`
placeholders). Line 1 is the version marker. Sections and fields (every §12
item; **no clone path**):

```markdown
<!-- tsf-config-version: FILLED-BY-INIT -->
# tsf Project Configuration

> Read by /tsf:cycle, /tsf:spec and the tsf agents at runtime. /tsf:init writes it; keep it accurate.

## Project profile
### Tech stack
### Commands
- **Build:** … / **Test:** … / **Lint:** …
### Code conventions
### Commit convention

## GitHub
- **Repository:** `owner/repo`
- **Base branch:** `main`
- **Branch pattern:** `gh-<n>` [must contain `<n>`; the canonical ticket ID stays `GH-<n>`]
- **Factory login:** `…` [the machine account that authors every factory PR]
- **Credential source:** `env` | `proxy` [env: GH_TOKEN exported in the factory clone's environment — from: …; proxy: injected by repository URL, the helper passes nothing]
- **Responders:** `login1`, `login2` [replies by these logins count as the human's answer; default: repository owner]
- **Comment pickup:** `workflow` | `polling`

## Environment contract
[Paths relative to the project root; each must exist and be executable.]
- **prepare:** `…`   (`prepare <branch> <base-branch>`)
- **env_up:** `…`
- **env_reset:** `…`
- **verify:** `…`
- **env_check:** `…` | [not registered]
- **Verification mode:** `local` | `ci`

## Constants
- **verify_fix_bound:** 3
- **gate_fix_bound:** 3
```

#### 2. Contract-script skeletons

**Files**: `plugins/tsf/templates/tsf/scripts/{prepare,env_up,env_reset,verify,env_check}.sh` (new, executable)
**Changes**: Each opens with a comment stating the contract (DESIGN.md §8
wording), the argument signature, and what the project must fill in.

- `prepare.sh`: `BRANCH="${1:?…}"; BASE="${2:?…}"`; `git reset --hard`,
  `git clean -fd` (ignored files stay), `git fetch --prune origin`, checkout
  `origin/$BRANCH` if it exists else `git checkout -B "$BRANCH" "origin/$BASE"`,
  then drop local branches whose upstream is gone. Comment: "this is the
  project's one sanctioned hard reset; keep your deny rules for ad-hoc
  `git reset --hard` in place".
- `env_up.sh`: comment "services only, idempotent"; body `exit 0` with a TODO.
- `env_reset.sh`: comment with the "suite manages its own state → record that
  fact and exit 0" case; body `exit 0` with a TODO.
- `verify.sh`: comment "the same command CI runs"; body
  `echo "verify: not configured — edit $0" >&2; exit 1` (a skeleton must
  never report green).
- `env_check.sh`: fast probe; body `exit 0` with a TODO.

#### 3. Comment-pickup workflow

**File**: `plugins/tsf/templates/github/tsf-comment-pickup.yml` (new)
**Changes**:

```yaml
name: tsf comment pickup
on:
  issue_comment:
    types: [created]
permissions:
  issues: write
jobs:
  relabel:
    if: >-
      ${{ !github.event.issue.pull_request
          && (contains(github.event.issue.labels.*.name, 'tsf:needs-answer')
              || contains(github.event.issue.labels.*.name, 'tsf:needs-plan-approval'))
          && contains(fromJSON('__TSF_RESPONDERS_JSON__'), github.event.comment.user.login) }}
    runs-on: ubuntu-latest
    steps:
      - name: Swap the human-side label for tsf:answered
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
          NUMBER: ${{ github.event.issue.number }}
        run: |
          current=$(gh api "repos/$REPO/issues/$NUMBER" --jq '[.labels[].name]')
          next=$(printf '%s' "$current" | jq -c '[.[] | select(. != "tsf:needs-answer" and . != "tsf:needs-plan-approval")] + ["tsf:answered"]')
          printf '{"labels":%s}' "$next" | gh api -X PUT "repos/$REPO/issues/$NUMBER/labels" --input -
```

`__TSF_RESPONDERS_JSON__` is replaced by `/tsf:init` with a JSON array of the
configured responders (e.g. `["tobyS"]`). Header comment: fires only from the
default branch; pushing it needs the `workflow` scope; the built-in token
cannot trigger further runs (no recursion); non-responder comments produce a
skipped run. Installed to `.github/workflows/tsf-comment-pickup.yml`.

### Success Criteria:

#### Automated Verification:

- [x] `head -1 plugins/tsf/templates/tsf/config.md` is `<!-- tsf-config-version: FILLED-BY-INIT -->`
- [x] `grep -c 'clone' plugins/tsf/templates/tsf/config.md` is 0 (no clone path)
- [x] All five skeletons are executable and pass `bash -n`; `verify.sh` exits 1 when run
- [x] The workflow parses as YAML (`ruby -ryaml -e 'YAML.load_file(ARGV[0])' plugins/tsf/templates/github/tsf-comment-pickup.yml` or `yq`) and contains `permissions:` with `issues: write`, `!github.event.issue.pull_request`, both label names and `__TSF_RESPONDERS_JSON__`
- [x] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] In the scratch repository, install the workflow on the default branch with the scratch responder baked in; a responder comment on a `tsf:needs-answer` issue swaps the label to `tsf:answered`; a comment by the factory account changes nothing

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `24e452a` feat(TP-0034a): add the tsf project templates
- **Did**: `templates/tsf/config.md` (no clone path; the word is avoided so
  the criterion holds), the five contract skeletons under
  `templates/tsf/scripts/` (`prepare` creates a missing branch `--no-track`
  from `origin/<base>` so pruning never drops it), and
  `templates/github/tsf-comment-pickup.yml`.
- **Issues**: none.
- **Verification**: ✅ 14 template checks, ✅ `prepare.sh` against a scratch
  bare remote (create, reset/clean keeps ignored, existing branch, prune,
  idle on base), ✅ validate

---

## Phase 4: Reference templates

### Overview

The document skeletons every agent and command reads **at the point of use**
(DESIGN.md §6), plus the result-block contract. One file per template under
`plugins/tsf/references/templates/`, each with the reference preamble
(readers, "changes are contract changes", `Contents:`), the skeleton in a
four-backtick fence.

### Changes Required:

#### 1. `spec.md`

**File**: `plugins/tsf/references/templates/spec.md` (new)
**Changes**: `# GH-<n>: <title>`, `## Problem`, `## Desired outcome`
(observable), `## Scope` (in / out), `## Anchors` (concrete pointers into the
system), `## Open questions` (numbered; the parking agent writes them here
before returning the question comment), `## Decisions` (dated entries where
answers are folded: "2026-…: Q1 → …"). The sufficiency minimum (scope,
observable outcome, one anchor) is stated in the preamble in tsf's own words.

#### 2. `research.md`

**File**: `plugins/tsf/references/templates/research.md` (new)
**Changes**: Frontmatter-free; `# Research: GH-<n>`, `## Summary`,
`## Findings` (file:line evidence), `## Constraints`, `## Impact`,
`## Options` (only where genuinely open), `## Open questions` (numbered),
`## Revisions` (dated, for the resume re-validation: what the answers changed).
Documentarian register stated in the preamble.

#### 3. `plan.md`

**File**: `plugins/tsf/references/templates/plan.md` (new)
**Changes**: `# Plan: GH-<n>`, `## Understanding`, `## Decisions` (taken, with
the rejected alternative one line each), `## Increments` — each
`### Increment <k>: <name>` with `**What changes**`, `**Where**` (research
evidence), `**Verification**` (automated command(s); `**Manual**` flagged
explicitly), `**Depends on**` (only when a real dependency exists) —
`## Open questions`, `## Feedback` (dated folds of plan-gate replies),
`## Addenda` (empty in slice 1; slice 2's deviation addenda). Preamble states
the §6.5 rules: increments are independently verifiable, unordered unless a
dependency is stated.

#### 4. `journal-entry.md`

**File**: `plugins/tsf/references/templates/journal-entry.md` (new)
**Changes**: The entry the dispatcher appends (heading composed by the
dispatcher, body from the agent's `tsf-journal` block):

```markdown
## Cycle <YYYY-MM-DDTHH:MMZ> — step: <triage|research|plan>
- Outcome: <one line>
- Questions asked: none (gate skipped: nothing to ask) | <k> (parked)
- Commits: <sha…> | none
- Label: <the tsf:* label set by this cycle>
- Next step: <triage|research|plan|implement>
```

`Next step` is the derived state (§3.3): the step the dispatcher runs next —
for a parked ticket, the parking step itself (decision 2). Vocabulary is
closed; the dispatcher rejects anything else.

#### 5. `question-comment.md`

**File**: `plugins/tsf/references/templates/question-comment.md` (new)
**Changes**: Two sections. (a) The question comment: informed understanding,
key findings, the numbered questions **in full**, then "Reply to this comment
with your answers (e.g. `1. …`). Only replies by <responders> are picked up."
(b) The plan summary, same shape plus decisions taken / alternatives rejected
(one line each), anything irregular, numbered questions if any, links
`[plan.md](https://github.com/O/R/blob/B/thoughts/factory/GH-N/plan.md)` and
`[research.md](…)`, **never the increment list**, and the closing line "Reply
`approved` to approve the plan; anything else is treated as feedback and the
plan is revised." A distillation resume prefixes the comment with the one-line
confirmation ("Folded your answers into spec.md (commit `abc1234`).").

#### 6. `result-block.md` — the machine contract

**File**: `plugins/tsf/references/templates/result-block.md` (new)
**Changes**: What every worker returns and what the dispatcher parses:

````markdown
```tsf-result
step: research
outcome: continued | parked | blocked
next-step: plan
next-label: tsf:plan
commits: abc1234 def5678 | none
summary: <one line for the closing report>
```
```tsf-comment
<the step's single comment, markdown, no angle brackets — the question comment,
the plan summary, or a two-sentence outcome comment>
```
```tsf-journal
- Outcome: …
- Questions asked: …
- Commits: …
- Label: tsf:plan
- Next step: plan
```
````

Parsing rules (the dispatcher's): take the **last** occurrence of each fence
by info string; ignore everything outside them (including a leading
`[harness: …]` line); replace `<\` with `<` inside `tsf-comment` (harness
escaping); `next-label` must be one of the labels the step may set (triage:
`tsf:needs-answer`, `tsf:research`; research: `tsf:needs-answer`, `tsf:plan`;
plan: `tsf:needs-plan-approval`, `tsf:implement`; any: `tsf:needs-human` with
`outcome: blocked`); `next-step` must be in the journal vocabulary. A missing
or malformed block → re-dispatch the same agent **once** with the note "your
previous return had no valid result block"; a second failure → park
`tsf:needs-human` with a journal entry naming the malformed return.

### Success Criteria:

#### Automated Verification:

- [x] Six files exist under `plugins/tsf/references/templates/`; each starts with `<!--` and contains `Contents:`
- [x] `grep -c '^````' plugins/tsf/references/templates/result-block.md` ≥ 2 (four-backtick outer fence)
- [x] `grep -n '<' plugins/tsf/references/templates/result-block.md` shows angle brackets only inside placeholder text of the parsing rules, none inside the three inner fences
- [x] `grep -q 'Next step' plugins/tsf/references/templates/journal-entry.md`
- [x] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] Read each template as the consuming agent would and confirm nothing project-specific or stack-specific appears

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `9585939` feat(TP-0034a): add the tsf reference templates
- **Did**: `references/templates/{spec,research,plan,journal-entry,
  question-comment,result-block}.md`. Additions over the plan: the journal
  template also defines the dispatcher-only entries (state mismatch, failed
  write, malformed return); the result block carries an allowed-outcomes
  table the dispatcher validates against; comments forbid nested code fences
  (they would close the `tsf-comment` fence); a twice-malformed return parks
  with a one-line dispatcher comment so the human sees why.
- **Issues**: none.
- **Verification**: ✅ preambles/Contents, ✅ four-backtick wrapper, ✅ no
  angle brackets inside the result fences, ✅ validate

---

## Phase 5: Worker agents

### Overview

`agents/triage.md`, `agents/research.md`, `agents/plan.md` (namespaced
`tsf:triage`, `tsf:research`, `tsf:plan`). Each carries the §6 common
contract, its §6.x step spec as its system prompt, resume-with-reply
behaviour (decision 2), the three-part constraint envelope, and the shipped
frontmatter below.

### Changes Required:

#### 1. Shared frontmatter and structure

```yaml
---
name: triage            # research | plan
description: Internal to `/tsf:cycle` — not for direct use. <one sentence on the step>. Returns a result block.
tools: Read, Write, Edit, Grep, Glob, Bash
model: sonnet           # plan: opus
---
```

`name` never contains `:`. `Agent` is deliberately absent from `tools`
(decision 3). Body order: role paragraph (ships in the tsf plugin,
project-agnostic, runs in the factory clone on the ticket branch) →
`## CRITICAL: YOUR ONLY JOB IS TO …` (with `DO NOT` bullets: push, run `gh`,
set labels, post comments, edit the issue, read GitHub, ask the user, spawn
agents, touch files outside `thoughts/factory/GH-<n>/` except where the step
says; one `ONLY …`) → `## What you receive` (the spawn-prompt fields) →
`## Project context` (read `.claude/tsf/config.md` from disk for the profile
and commit convention; hard stop if missing) → `## Process` → `## Commit
rules` (`git add` only the step's files, one commit in the project's
convention, scope `GH-<n>`, e.g. `docs(GH-12): add research`) → `## Return`
(read `${CLAUDE_PLUGIN_ROOT}/references/templates/result-block.md` **now — in
full** and emit exactly that; nothing else after it) → `## What NOT to Do` →
`## REMEMBER: You are a <step> worker, not the dispatcher`.

Spawn-prompt fields every agent expects (the dispatcher passes exactly these,
Phase 8): `ticket: GH-<n>`, `branch:`, `base-branch:`, `mode: fresh | resume`,
`repo: <owner>/<repo>` (for file links), `responders:`; triage additionally
`issue-title:` and `issue-body:` (verbatim); resume additionally `reply:`
(verbatim responder text). Every input artifact is **re-read from disk in
chain order** on every dispatch, never assumed.

#### 2. `tsf:triage` (§6.2)

- Fresh: read the template (`references/templates/spec.md`, point of use),
  distill the issue body into `thoughts/factory/GH-<n>/spec.md`, test
  sufficiency (scope / observable outcome / anchor). Insufficient → write the
  numbered questions into the spec's "Open questions", commit
  (`docs(GH-<n>): add spec`), return `outcome: parked`, `next-label:
  tsf:needs-answer`, `next-step: triage`, comment = question comment
  (template read at point of use). Sufficient → commit, return `continued`,
  `tsf:research`, `next-step: research`, a two-sentence comment.
- Resume: read `spec.md`, pair the reply with its "Open questions", fold each
  answer into the body and a dated "Decisions" entry, clear answered
  questions, re-test sufficiency; commit `docs(GH-<n>): fold answers into
  spec`; the comment's first line is the confirmation. Unanswered questions
  are re-asked (parked again).

#### 3. `tsf:research` (§6.4)

- Fresh: read `spec.md`; research the codebase inline (Grep/Glob/Read; Bash
  only for read-only project commands and `git log/diff/show`); write
  `research.md` from the template; open questions that materially affect
  planning → numbered in `research.md` **and** in `spec.md`'s "Open
  questions" (decisions belong in the spec, §6.3), commit, `parked` /
  `tsf:needs-answer` / `next-step: research`. Otherwise `continued` /
  `tsf:plan` / `next-step: plan`, journal "gate skipped: nothing to ask".
- Resume (decision 2): fold the reply into `spec.md` (body + "Decisions"),
  re-validate `research.md` against the updated spec — amend findings the
  answers change, record what changed under "Revisions" — commit, then
  `tsf:plan` or a second batch.

#### 4. `tsf:plan` (§6.5)

- Fresh: read `spec.md` → `research.md`; write `plan.md` as self-verifying
  increments; commit; comment = plan summary (second section of the
  question-comment template, links to `plan.md`/`research.md` on the branch,
  never the increment list); `parked` / `tsf:needs-plan-approval` /
  `next-step: plan`.
- Resume: read `spec.md` → `research.md` → `plan.md`, then classify the reply.
  **Approving** (the reply's substantive content is an approval — `approved`,
  `LGTM`, "go ahead" and the like, with no change request) → no plan change,
  `continued`, `next-label: tsf:implement`, `next-step: implement`, comment
  "Plan approved; implementation is next." Anything else → fold into
  `plan.md` "Feedback" (dated), revise the affected increments, commit
  `docs(GH-<n>): revise plan`, re-summarize, `parked` /
  `tsf:needs-plan-approval` / `next-step: plan`. Questions the plan must ask
  go into the summary's numbered questions (§6.5), never a separate park.

### Success Criteria:

#### Automated Verification:

- [x] Three files in `plugins/tsf/agents/`; each frontmatter has `name:` without `:`, `description:` starting with `` Internal to `/tsf:cycle` — not for direct use ``, `tools: Read, Write, Edit, Grep, Glob, Bash` exactly, and `model:` = `sonnet` (triage, research) / `opus` (plan) — `grep -n '^model:' plugins/tsf/agents/*.md`
- [x] `grep -L 'Agent' plugins/tsf/agents/*.md` — no `tools:` line contains `Agent` (`grep -n '^tools:.*Agent' plugins/tsf/agents/*.md` is empty)
- [x] Each file has the three envelope headings (`## CRITICAL:`, `## What NOT to Do`, `## REMEMBER:`)
- [x] Each file reads `result-block.md` with the point-of-use phrasing (`grep -c 'references/templates/result-block.md' plugins/tsf/agents/*.md` ≥ 1 each)
- [x] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] In the scratch project with the plugin installed, dispatch `tsf:triage` from a plain prompt ("Use the tsf:triage agent, passing …") on a throwaway issue body and confirm: it works on a branch, commits `spec.md`, returns the three fences and nothing after; the subagent transcript's `message.model` shows the sonnet pin (TP-0029 runbook: `~/.claude/projects/<project>/<session>/subagents/agent-<id>.jsonl`) — and once for `tsf:plan` showing opus
- [ ] The namespaced dispatch phrasing (`tsf:triage`) resolves to the plugin agent (the Agent tool's `subagent_type` list shows `tsf:triage`); if only the bare name resolves, switch the phrasing in Phase 8 and note it in the plan closeout

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `039328f` feat(TP-0034a): add the tsf triage, research and plan agents
- **Did**: `agents/{triage,research,plan}.md` with the §6 contract, the
  three-part envelope, fresh/resume processes and point-of-use template reads.
  Addition: the spawn payload gains `templates:` (the dispatcher's expanded
  `${CLAUDE_PLUGIN_ROOT}/references/templates`) as a fallback should the
  variable not be substituted in agent bodies; a branch mismatch or missing
  config/input returns `outcome: blocked`; a re-queued ticket with an existing
  artifact treats it as the earlier draft.
- **Issues**: none.
- **Verification**: ✅ frontmatter/pins/tools greps, ✅ envelope headings,
  ✅ result-block reads, ✅ validate

---

## Phase 6: `/tsf:init`

### Overview

The interactive setup command, modelled on `plugins/tce/commands/init.md`
(preamble write gate, `## What gets created`, Phases 0–4, `## Idempotency`,
`## Notes`). Flagged. Runs in the human's working copy under the ambient
login; the factory credential is checked from the configured source.

### Changes Required:

#### 1. Frontmatter

```yaml
---
description: Set up tsf in this project — analyze it, agree the GitHub coordinates, factory identity, responders and environment contract, write .claude/tsf/config.md, create the tsf:* labels, check the factory credential, and offer the allowlist and the comment-pickup workflow.
argument-hint: ""
disable-model-invocation: true
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-read.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh":*), Bash(git remote:*), Bash(git symbolic-ref:*), Bash(git log:*), Bash(git branch:*)
---
```

#### 2. Body

**File**: `plugins/tsf/commands/init.md` (new)

- Preamble: "Do not write any files until the user confirms (Phase 4)";
  `## Project context` (read `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`
  for the version; read `.claude/tce/profile.md` **only as a seed** when
  present, §2); the `### AskUserQuestion dialog guidelines` block copied
  **byte-identically** from `plugins/tce/commands/plan.md` (heading through
  last bullet); `## What gets created` tree (`.claude/tsf/config.md`; on
  confirmation: contract skeletons at the chosen paths, the workflow at
  `.github/workflows/tsf-comment-pickup.yml`, the `permissions.allow` entries
  in `.claude/settings.json`).
- **Phase 0 Preflight**: `command -v git`, `gh`, `jq` one-liners; all three
  required for tsf (gh for `gh api`, jq for the scripts) — say what breaks;
  continue.
- **Phase 1 Analyze** (evidence-file enumerations, "only a suggestion"):
  stack/commands/conventions/commit convention (seeded from the tce profile
  when present, else the same heuristics tce's init uses, in tsf's words);
  GitHub coordinates from `git remote get-url origin` (parse `owner/repo`
  from https and ssh forms); base branch from `git symbolic-ref --short
  refs/remotes/origin/HEAD` → else current branch; branch pattern guessed
  from `git branch -r` names containing an issue number (e.g. `gh-12` →
  `gh-<n>`), else propose `gh-<n>`; responders default = repository owner
  (the `owner` half of the coordinates); existing `tsf:*` labels are not
  queried here — `label-create`'s `created|updated` result in Phase 4 tells;
  existing contract scripts by scanning
  for the five names under `scripts/`, `.claude/tsf/scripts/`, `bin/`;
  existing `.github/workflows/tsf-comment-pickup.yml`; existing
  `.claude/tsf/config.md` and its marker (→ Idempotency).
- **Phase 2 Propose**: the fenced report; then dialogs with **verbatim copy**
  in the four-part frame for: (a) factory identity — login + credential
  source (`env` recommended unless a proxy is detected: describe how to tell
  — e.g. a `GH_TOKEN` that is a placeholder, or the user says so), (b)
  responders (detected owner first, multi-select from collaborators is not
  queried — free text), (c) contract-script locations — for each of the five
  commands, options "Use detected `<path>`" / "Create a skeleton at
  `.claude/tsf/scripts/<name>.sh`" / "I will provide it later" (the last
  means init cannot finish), (d) verification mode (`local` recommended when
  `verify` exists), (e) comment pickup (`workflow` recommended; explain the
  default-branch and `workflow`-scope facts), (f) allowlist write (approve
  the listed `permissions.allow` entries, decision 6), (g) foreground
  requirement acknowledged.
- **Phase 3 Refine**: iterate; for each **missing** mandatory command explain,
  from the analysis, what the script has to do for *this* project (the git
  sequence for `prepare`; the services for `env_up`; what "clean baseline"
  means here incl. the suite-manages-its-own-state case for `env_reset`; the
  CI command for `verify`), and offer the skeleton.
- **Phase 4 Write (after explicit confirmation)**, in order:
  1. `mkdir -p .claude/tsf`, `cp "${CLAUDE_PLUGIN_ROOT}/templates/tsf/config.md" …`,
     fill every field, stamp the marker from the manifest version ("the
     template is the single source of truth for the structure").
  2. Skeletons: `cp` each confirmed skeleton to its path, `chmod +x`.
  3. **Contract check**: run `preflight.sh` with the registered paths (no
     `--foreground`, no `--identity`); `result: incomplete` → print per
     missing command what is still needed and how to re-run, and **stop
     without declaring init finished** (config.md stays written so a re-run
     resumes; say so).
  4. **Labels**: `gh-write.sh label-create --as ambient` for the fourteen
     labels of DESIGN.md §3.4 with the family colours — factory `d4d4d4`
     (`tsf:queued`, `tsf:research`, `tsf:plan`, `tsf:implement`,
     `tsf:verify`, `tsf:dossier`, `tsf:rework`, `tsf:landing`,
     `tsf:answered`), human `d73a4a` (`tsf:needs-answer`,
     `tsf:needs-plan-approval`, `tsf:needs-review`, `tsf:needs-human`),
     modifier `fbca04` (`tsf:priority`); descriptions = the §3.4 "Meaning"
     column. Report created/updated per label; any `denied|rejected|failed`
     stops with the detail.
  5. **Factory credential check**: ask the user to make the factory
     credential resolvable in this session per the configured source (env:
     `export GH_TOKEN=<factory token>` before re-running this step; proxy:
     nothing to do), then run `preflight.sh --identity --repo … --as factory
     --credential … --factory-login … --responders …` with the mandatory
     script flags. `identity: ok` → continue; `mismatch` (login differs) or
     `responder` → **stop**: explain (the human would review their own PRs);
     `unavailable` → the user may defer: print it under "still needed" and
     continue (the cycle re-checks every run).
  6. **Allowlist** (decision 6): compute the entries —
     `Bash(<prepare path>:*)`, `Bash(<env_up>:*)`, `Bash(<env_reset>:*)`,
     `Bash(<verify>:*)`, `Bash(<env_check>:*)` if registered, plus the
     workers' local git (`Bash(git add:*)`, `Bash(git commit:*)`,
     `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(git show:*)`,
     `Bash(git status:*)`, `Bash(git rev-parse:*)`) and the project's test/
     lint/build commands from the profile as `Bash(<cmd>:*)`. **Never**
     `git push`, never `gh`. Show the exact diff; on approval edit
     `.claude/settings.json` surgically: create the file with only
     `permissions.allow` if absent; otherwise append missing entries to the
     existing array, no duplicates, every other key byte-identical.
  7. **Workflow**: on confirmation copy the template to
     `.github/workflows/tsf-comment-pickup.yml` replacing
     `__TSF_RESPONDERS_JSON__` with the responders as a JSON array; state
     that it fires only once on the default branch and that pushing it
     needs the `workflow` scope; until then polling applies (set `Comment
     pickup: polling` if declined).
  8. **Checklists** (printed, manual, the ruleset shape): (a) repository
     ruleset — PR required, one approving review, required check with strict
     up-to-date, no bypass for the factory login, delete-branch-on-merge,
     and the CI workflow **must not path-filter `thoughts/**`**; (b) the
     factory clone — a second clone at a path the sandbox's filesystem grant
     covers, per-checkout ports for `env_up`, `export
     CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` and (env source) `export
     GH_TOKEN=…` in the shell that starts the runner, open `claude` **in the
     clone**, run `/tsf:cycle` once, then `/loop /tsf:cycle`; the clone is
     the factory's alone. (c) Next: `/tsf:spec` for the first ticket.
  9. Do **not** commit automatically; list the files to commit.
- `## Idempotency`: never clobber; marker comparison — same version →
  "already up to date (v0.1.0)", offer to re-run the checks (contract,
  labels, credential) without rewriting config; older/missing marker → walk
  through the upgrade list, then update the marker. Upgrade list: `0.1.0 —
  initial release; nothing to migrate`. **When a later version changes
  required config, extend this list in the same commit.**
- `## Notes`: the one `settings.json` write is the approval-gated allowlist
  append (decision 6); init never edits anything else there; never touches
  `thoughts/`.

### Success Criteria:

#### Automated Verification:

- [x] Frontmatter: `disable-model-invocation: true` present; `allowed-tools` grants only the three scripts and the listed read-only git commands (`grep -n 'git push\|gh api\|gh ' plugins/tsf/commands/init.md` shows no grant of `git push` or bare `gh`)
- [x] The AskUserQuestion block is byte-identical to `plugins/tce/commands/plan.md`'s (extract heading through last bullet with `awk`/`sed` and `diff`)
- [x] `grep -c 'templates/tsf/config.md' plugins/tsf/commands/init.md` ≥ 1; `grep -q 'tsf-config-version' …`; `grep -q 'CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1' …`; `grep -q 'thoughts/\*\*' …` (the no-path-filter requirement)
- [x] All fourteen label names from DESIGN.md §3.4 appear in the file (`for l in queued research plan implement verify dossier rework landing answered needs-answer needs-plan-approval needs-review needs-human priority; do grep -q "tsf:$l" … || echo MISSING $l; done`)
- [x] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] In the scratch project: `/tsf:init` with one contract script deliberately missing stops with the per-command explanation and a re-run hint; after adding it, re-run reports "already up to date", offers the checks, creates/updates the labels, verifies the factory account (a deliberate responder = factory login is refused), writes the allowlist diff only after approval and leaves other `settings.json` keys untouched, installs the workflow with the responders baked in, prints both checklists

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `5cc83be` feat(TP-0034a): add /tsf:init
- **Did**: `commands/init.md` — Phases 0–4, Idempotency (same version → re-run
  steps 2–8, which is how a stopped init finishes), Notes. Refinements: the
  default responder is the ambient `whoami` login; the foreground requirement
  is part of the confirmed proposal and checklist rather than its own dialog;
  the credential check offers a `!`-prefixed run with the token read inline
  (this session is the human's and normally has no factory `GH_TOKEN`); the
  allowlist adds `git branch` and `Edit(thoughts/factory/**)` for unattended
  runs.
- **Issues**: none.
- **Verification**: ✅ frontmatter grants, ✅ AskUserQuestion block identical
  to all ten existing copies, ✅ config/marker/foreground/path-filter greps,
  ✅ fourteen labels, ✅ validate

---

## Phase 7: `/tsf:spec`

### Overview

The interactive entry door (§6.1): guided spec authoring to the sufficiency
minimum, then issue → branch → spec commit → marker block over REST through
`gh-write.sh --as ambient`, and the `tsf:queued` offer. Flagged. Touches no
checkout.

### Changes Required:

#### 1. Frontmatter

```yaml
---
description: Author a factory spec through guided discussion, then create the ticket triple — GitHub issue, ticket branch and thoughts/factory/GH-<n>/spec.md — over REST under your own login, and offer to release it with tsf:queued.
argument-hint: "[what to build]"
disable-model-invocation: true
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-read.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh":*)
---
```

#### 2. Body

**File**: `plugins/tsf/commands/spec.md` (new)

- `## Project context`: read `.claude/tsf/config.md` **now, in full**; missing
  → "run `/tsf:init`" and stop. Take repository, base branch, branch pattern,
  responders, commit convention from it. The AskUserQuestion block, byte-
  identical.
- `## Initial Response`: with an argument, start; without, the fenced usage
  message ("Tell me what you want built…", `Tip:`).
- **Authoring**: iterate WHAT and WHY with the user; push for the sufficiency
  minimum (clear scope, observable outcome, at least one concrete anchor);
  read `${CLAUDE_PLUGIN_ROOT}/references/templates/spec.md` **now — in full**
  before drafting; present the draft spec, the issue title and a 2–4 sentence
  human summary; refine until confirmed. No file is written locally.
- **Create the triple** (each step's `result:` checked; any non-ok → show the
  detail and stop, listing what exists so far):
  1. `gh-write.sh issue-create --as ambient --repo … --title … --body-file <temp>` → `number: n`; canonical ID `GH-n`.
  2. Branch name from the pattern (`gh-<n>` → `gh-n`); `ref-create --branch gh-n --from <base>`.
  3. `contents-put --branch gh-n --path thoughts/factory/GH-n/spec.md --file <temp> --message "docs(GH-n): add spec"` (message in the project's commit convention).
  4. `marker --issue n --ticket GH-n --branch gh-n` (spec + branch links; the block is appended after the branch exists because its name derives from the issue number, §3.2/§6.1).
  5. Offer `labels --issue n --set tsf:queued --as ambient` (dialog: Release now (Recommended) / Keep unreleased).
- Print the issue URL, branch, spec path, and "next: the factory picks it up
  on its next cycle" / "release later by adding `tsf:queued`".
- `## Important Rules`: ambient login deliberately (issues and specs are the
  human's); never touch the working copy or a clone; never `gh` porcelain;
  temp files in the scratchpad.

### Success Criteria:

#### Automated Verification:

- [x] Frontmatter: flagged; `allowed-tools` grants exactly the two read/write scripts
- [x] AskUserQuestion block byte-identical (same diff check as Phase 6)
- [x] `grep -q -- '--as ambient' plugins/tsf/commands/spec.md`; `grep -q 'ref-create' …`; `grep -q 'contents-put' …`; `grep -q 'references/templates/spec.md' …`
- [x] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] In the scratch project (human working copy, ambient login): `/tsf:spec` produces an issue authored by the human, a branch `gh-<n>` at the base head plus one commit containing `thoughts/factory/GH-<n>/spec.md`, the marker block appended below the untouched summary, and — after "Release now" — the `tsf:queued` label; the local working copy shows no change (`git status` clean, no new branch)

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `ad1a1fb` feat(TP-0034a): add /tsf:spec
- **Did**: `commands/spec.md` — config read, Initial Response, authoring to the
  sufficiency minimum from the spec template, the five-step triple creation
  over `gh-write.sh --as ambient` (issue → branch → spec commit → marker →
  release dialog), report and rules. `ref-create` → `exists` stops rather than
  committing onto a branch spec did not create.
- **Issues**: none.
- **Verification**: ✅ frontmatter, ✅ AskUserQuestion block identical,
  ✅ ambient/ref-create/contents-put/template greps, ✅ validate

---

## Phase 8: `/tsf:cycle`

### Overview

The dispatcher (§5.1) for rows 1–4 and 13, unflagged, thin, one cycle per
turn. The body holds the invariants, the preflight, scan, pick, prepare,
decide, dispatch, write and report steps; the row details, the write phase
and the report format are three reference files read at point of use so the
body stays under the compaction budget.

### Changes Required:

#### 1. Frontmatter

```yaml
---
description: Run one factory cycle — scan the tsf:* backlog over REST, pick the highest-priority actionable ticket, advance it exactly one step in a fresh agent context, and perform every GitHub write. Re-invoke it with /loop /tsf:cycle.
argument-hint: ""
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-read.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/push.sh":*), Bash(git add:*), Bash(git commit:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git status:*)
---
```

**No `disable-model-invocation`** — the flag is never written as `false`, it
is omitted (tle precedent). No `model:`.

#### 2. Body

**File**: `plugins/tsf/commands/cycle.md` (new; target ≤ 230 lines and
≤ 18,000 bytes)

- H1, role paragraph, then **`## Invariants`** *before* `## Project context`
  with the precedence clause ("These govern everything below…"):
  1. One cycle per turn: perform exactly one step for one ticket, then end
     the turn with the closing report. Never loop internally.
  2. Foreground only: every agent dispatch is foreground and the cycle waits
     for it; the preflight refuses to run without
     `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`. No background shell.
  3. No content work: never read the spec, research or plan bodies, never
     write artifact content; the dispatcher reads only labels, the journal's
     last entry, file existence, and result blocks.
  4. Everything from disk and REST, nothing from conversation memory: config,
     journal, scan — re-read every cycle.
  5. Every GitHub write goes through `gh-write.sh` / `push.sh` as the factory
     identity; agents never write to GitHub.
- `## Project context`: read `.claude/tsf/config.md` **now, in full**;
  missing → stop ("run `/tsf:init` in the human's working copy; the factory
  clone must contain the committed config"). Extract: repo, base branch,
  branch pattern, factory login, credential source, responders, comment
  pickup, contract paths, verification mode, constants. This session runs
  **in the factory clone** — the project directory (§5.3).
- **Step 1 Preflight**: `preflight.sh --prepare … --env-up … --env-reset …
  --verify … [--env-check …] --foreground --identity --repo … --as factory
  --credential … --factory-login … --responders …`. `result: incomplete` →
  print the `detail:` and end the cycle with the report (no scan, no write).
  Keep `now:` for the journal heading.
- **Step 2 Scan**: `scan.sh …` with `--poll --responders … --factory-login …`
  when comment pickup is `polling`. `result: failed` → report and end.
- **Step 3 Pick** (from scan data only; §5.2 applied to this slice):
  actionable = state in {`tsf:answered`, `tsf:queued`, `tsf:research`,
  `tsf:plan`} or (`tsf:needs-answer` | `tsf:needs-plan-approval` with
  `reply:` an id — treated as `tsf:answered`). Not actionable, skipped and
  named in the report: `tsf:needs-*` with no reply (row 13); `multiple` /
  `none` state (**reported only**, as "needs a single tsf:* state label" —
  fixing a human-made label set is a human write, §3.4); every later-slice
  state (`tsf:implement`,
  `tsf:verify`, `tsf:dossier`, `tsf:rework`, `tsf:landing`,
  `tsf:needs-review`) → "not implemented in this slice". Order: in-flight
  (state ≠ `tsf:queued`) before `tsf:queued`; `priority: yes` before `no`;
  oldest `created` first. None actionable → run `<prepare> <base> <base>`,
  report idle, end.
- **Step 4 Prepare**: `<prepare path> <branch> <base>` for the picked
  ticket's branch (from the pattern). Non-zero exit → journal cannot be
  written (no branch): report "prepare failed" with the output's last lines
  and end (no park — nothing to write to).
- **Step 5 Decide**: read `${CLAUDE_PLUGIN_ROOT}/references/cycle-dispatch.md`
  **now — in full** and follow it (rows, derived state, validation, resume,
  distillation mapping, the spawn payload per agent).
- **Step 6 Dispatch**: "Use the **tsf:<agent>** agent (foreground), passing
  exactly: …" (the payload from the reference), "Pass nothing else.",
  "**Wait for the agent to complete before continuing.**", then the
  `MANDATORY OUTPUT` check: the agent's return contains the three fences
  (parsing rules in `result-block.md`, read now); the artifact the step
  produces exists on disk (`spec.md` / `research.md` / `plan.md`).
- **Step 7 Write**: read `${CLAUDE_PLUGIN_ROOT}/references/cycle-write-phase.md`
  **now — in full** and perform it.
- **Step 8 Report and end**: read `${CLAUDE_PLUGIN_ROOT}/references/cycle-report.md`
  **now — in full**, print the report, end the turn. No question to the
  user, no next-steps menu.
- `## Important Rules`: the ID normalization (`#n`, `n`, URL → `GH-n`); never
  `gh` porcelain; never edit the issue body; never guess a state; later-slice
  rows are reported, never attempted.

#### 3. `references/cycle-dispatch.md`

**File**: `plugins/tsf/references/cycle-dispatch.md` (new)

- **Derived state**: on the checked-out branch, `journal.md`'s last entry
  (`## Cycle …` heading) and its `Next step:` line; artifacts = existence of
  `spec.md`, `research.md`, `plan.md`.
- **Rows for this slice** (evaluated in order):
  1. State `tsf:answered` (or a polled reply) → **distill+resume**: the
     parking step = the last journal entry's `step:`; target artifact by the
     fixed mapping (triage/research → `spec.md`; plan → `plan.md`); the
     resuming agent = the parking step's agent (decision 2); fetch the reply
     with `gh-read.sh reply` and pass it as `reply:` with `mode: resume`.
     A polled reply first gets `labels --set tsf:answered` (so the label
     history matches the workflow path), then proceeds. Parking step
     `implement` → not implemented in this slice (report, skip).
  2. `tsf:queued`, no `spec.md` → **triage** (`mode: fresh`, `issue-title:`
     and `issue-body:` from `gh-read.sh issue`).
  3. `tsf:queued` with `spec.md` and no `journal.md` → **research**.
     `tsf:queued` with a journal → resume at its `Next step` (`triage` →
     triage in `mode: resume` with an empty `reply:` — it re-tests the
     existing spec's sufficiency; `research` → research fresh; `plan` →
     plan fresh; `implement` → not implemented in this slice). `tsf:research`
     → **research**.
  4. `tsf:plan` → **plan**.
  13. `tsf:needs-*` without a reply → never reaches here (skipped at pick).
- **Validation**: factory-side label vs derived state disagree (e.g. label
  `tsf:research` but journal `Next step: plan` and `research.md` exists) →
  correct the label (`labels --set` to the derived one) and proceed with the
  derived step; human-side label disagrees with artifacts (e.g.
  `tsf:needs-plan-approval` but no `plan.md`; `tsf:answered` but no journal)
  → journal entry describing the mismatch, `labels --set tsf:needs-human`,
  report, end — never guess.
- **Spawn payload** per agent (exact field list from Phase 5), with the
  literal instruction that the agent must re-read its inputs from disk.

#### 4. `references/cycle-write-phase.md`

**File**: `plugins/tsf/references/cycle-write-phase.md` (new)

Ordered, each step's `result:` checked; on `failed|denied|rejected|mismatch`
→ **park**: `labels --set tsf:needs-human`, append a journal entry
("Outcome: write failed: <op> — <detail>", `Next step:` unchanged), commit,
`push.sh` (best effort), report. On a push failure the journal cannot reach
GitHub: report it prominently.

1. Validate the result block (vocabulary checks from `result-block.md`).
2. Journal: read `references/templates/journal-entry.md` now; append
   `## Cycle <now> — step: <step>` + the `tsf-journal` body to
   `thoughts/factory/GH-<n>/journal.md` (create with a `# Journal: GH-<n>`
   H1 if absent); `git add thoughts/factory/GH-<n>/journal.md`;
   `git commit -m "docs(GH-<n>): journal <step>"` (single `-m`, project
   convention type `docs`).
3. `push.sh --branch <branch> --credential <source>`.
4. `gh-write.sh marker --issue <n> --ticket GH-<n> --branch <branch> --journal`.
5. `gh-write.sh comment --issue <n> --body-file <scratch file holding the tsf-comment text>`.
6. `gh-write.sh labels --issue <n> --set <next-label>`.

Note the order (§5.1 step 6): the journal is committed and pushed *before*
the comment and label, so the comment's link to the journal resolves.

#### 5. `references/cycle-report.md`

**File**: `plugins/tsf/references/cycle-report.md` (new)

```markdown
## tsf cycle — <now>
- **Ticket:** GH-<n> — <step> (<old label> → <new label>): <summary line from tsf-result> | idle: nothing actionable
- **Writes:** journal <sha> pushed · marker updated · comment <id> · label <label>   | none
- **Skipped:** GH-<a> (tsf:needs-answer, no reply) · GH-<b> (tsf:implement — not implemented in this slice) · GH-<c> (needs a single tsf:* state label)
- **Preflight:** ok | <detail>
- **Suggested wait:** 1 minute (another actionable ticket remains) | 5 minutes (productive cycle, none remain) | 15 minutes (idle, parked tickets awaiting replies via polling) | 30 minutes (idle, nothing parked)
```

The suggested wait is plain text for the self-paced `/loop` to price in
(research: `ScheduleWakeup` is not callable from a command; the loop picks
the delay from what it observed). Nothing else is printed after the report.

### Success Criteria:

#### Automated Verification:

- [x] `grep -c 'disable-model-invocation' plugins/tsf/commands/cycle.md` is 0; `grep -c '^model:' …` is 0
- [x] `## Invariants` appears before `## Project context` (`grep -n` line numbers compare)
- [x] `wc -c plugins/tsf/commands/cycle.md` ≤ 18000 and `wc -l` ≤ 230
- [x] The three reference files exist and each is read with the point-of-use phrasing in `cycle.md` (`grep -c 'now — in full' plugins/tsf/commands/cycle.md` ≥ 4, counting `result-block.md`)
- [x] `allowed-tools` grants the five scripts and no `git push` / `gh` (`grep -n 'git push\|Bash(gh' plugins/tsf/commands/cycle.md` empty)
- [x] `grep -q 'not implemented in this slice' plugins/tsf/commands/cycle.md` and the same string in `cycle-report.md`
- [x] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] Without `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, `/tsf:cycle` ends after the preflight with the report naming `foreground: missing` and performs no scan or write
- [ ] End-to-end in the factory clone (Testing Strategy): a `tsf:queued` triple from `/tsf:spec` is researched (journal, marker with journal link, one comment, `tsf:plan`), planned and parked `tsf:needs-plan-approval` with a summary linking `plan.md`; a feedback reply (workflow path) leads to a revised plan and a second summary; an `approved` reply leads to `tsf:implement`; the next cycle reports it as not implemented in this slice and idles with a 30-minute suggested wait; with the workflow uninstalled and `Comment pickup: polling`, the same replies are picked up
- [ ] A raw issue labelled `tsf:queued` without a spec is triaged (branch created by `prepare` from base, spec committed and pushed), parked with numbered questions, and resumed after a reply with the answers folded into `spec.md`
- [ ] A ticket re-queued from `tsf:needs-human` resumes at the journal's `Next step`; a `tsf:needs-plan-approval` label on a ticket without `plan.md` is parked `tsf:needs-human` with a mismatch journal entry

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `<phase-8>` feat(TP-0034a): add /tsf:cycle and its dispatch references
- **Did**: `commands/cycle.md` (165 lines, ~8 KB) and `references/cycle-{dispatch,
  write-phase,report}.md`. Refinements: a derived step of `implement` found
  after prepare **re-picks** the next actionable ticket (writes nothing), so a
  later-slice ticket never ends a cycle while others are actionable; a failed
  `prepare` or push parks on GitHub only (comment + `tsf:needs-human`), since
  no journal can be pushed; `cycle.md` names the plugin root once because
  reference files are read without variable substitution; parked human-side
  labels are validated when a reply makes them actionable (a
  `tsf:needs-plan-approval` without `plan.md` is detected on the reply).
- **Issues**: none.
- **Verification**: ✅ unflagged/no model, ✅ invariants first, ✅ size,
  ✅ five point-of-use reads, ✅ no push/gh grants, ✅ slice string, ✅ validate

---

## Phase 9: Docs and governance

### Overview

Complete the README, record the same-commit spans in CLAUDE.md, and update
the two other plugin-enumerating surfaces. Root `README.md` catalog stays for
TP-0034c.

### Changes Required:

#### 1. `plugins/tsf/README.md`

Full consumer docs for slice 1: what tsf is (three paragraphs, pointing to
DESIGN.md), install, `/tsf:init` (what it writes, the checklists, the factory
clone and its two environment variables, the workflow), `/tsf:spec`,
`/tsf:cycle` and `/loop /tsf:cycle` (one cycle per turn, foreground
requirement, the closing report), the labels table, "Slice 1 scope" with the
not-implemented rows, the environment contract (five scripts, signatures),
troubleshooting (`identity: mismatch`, `foreground: missing`, proxy denial).

#### 2. `CLAUDE.md`

- Intro paragraph: four plugins; tsf is not dogfooded here (GitHub-issue
  projects with a factory clone; this repo uses tmt).
- Layout block: add the `plugins/tsf/` tree (commands, agents, references +
  `references/templates/`, scripts, `templates/tsf/` + `scripts/`,
  `templates/github/`, `DESIGN.md`).
- TP-0017 section: add the tsf classification (`init`, `spec` flagged;
  `cycle` **must never** carry the flag — `/loop` fires it as a prompt; the
  three agents unclassified).
- AskUserQuestion section: "ten" → "twelve" copies, adding
  `plugins/tsf/commands/{init,spec}.md` to the list.
- Testing changes: add `claude plugin validate ./plugins/tsf` and the tsf
  smoke-test outline (scratch GitHub repo, second account as factory
  identity, factory clone).
- New rule sections (each: the span, why, the RULE sentence):
  1. **tsf: the dispatcher owns every GitHub write (§11.3).** Span:
     `scripts/gh-write.sh` + `push.sh` (the only write paths), `commands/cycle.md`
     + `references/cycle-write-phase.md` (the callers), the three agents (never
     write; their `## CRITICAL` says so). Change the helper's subcommands or
     `result:` vocabulary → update `cycle.md`, `cycle-write-phase.md`,
     `spec.md`, `init.md` in the same commit.
  2. **tsf: the result block is a machine contract.** Span:
     `references/templates/result-block.md`, the three agents' `## Return`,
     `cycle.md` step 6 and `cycle-write-phase.md`.
  3. **tsf: the journal's `Next step` is the derived state.** Span:
     `references/templates/journal-entry.md`, `cycle-dispatch.md`, the agents'
     `tsf-journal` vocabulary. The closed vocabulary grows only with a slice.
  4. **tsf: the environment contract check.** Span: `scripts/preflight.sh`,
     `commands/init.md` (Phase 4 step 3), `commands/cycle.md` (step 1),
     `templates/tsf/scripts/*` (signatures), README. Change a command's name
     or signature → all five in the same commit. The `prepare <branch>
     <base-branch>` signature is the contract.
  5. **tsf: `/tsf:init`'s allowlist append is the repo's second sanctioned
     `settings.json` edit** (approval-gated, surgical, never `git push`,
     never `gh`).
  6. **tsf: `config.md` is prose-only; scripts take arguments.** No tsf
     script reads `.claude/tsf/config.md` (the `branch.sh` division of
     labour); the command resolves values and passes them.
  7. **tsf: agent pins are policy** — `triage`/`research` `sonnet`, `plan`
     `opus`, aliases only, `Agent` omitted from `tools` (workers inline).
- Releasing: no change (the `0.x` staging rule already covers tsf).

#### 3. `CONTRIBUTING.md`

Add `plugins/tsf/` to the repository-layout tree (`:32-57`).

#### 4. `.claude/tce/profile.md`

Code map rows: add `plugins/tsf/commands/`, `plugins/tsf/agents/`,
`plugins/tsf/scripts/`, `plugins/tsf/references/`, `plugins/tsf/templates/`;
the "three plugins" sentence → four, with tsf's one-liner and "not used here";
the Test command line adds `./plugins/tsf`.

### Success Criteria:

#### Automated Verification:

- [ ] `grep -c 'plugins/tsf' CLAUDE.md` ≥ 5; `grep -q 'twelve' CLAUDE.md` and `grep -c 'ten commands\|ten copies' CLAUDE.md` is 0
- [ ] `grep -q 'plugins/tsf' CONTRIBUTING.md`; `grep -q 'plugins/tsf' .claude/tce/profile.md`; `grep -c 'three plugins' .claude/tce/profile.md` is 0
- [ ] The AskUserQuestion block is byte-identical across all **twelve** files (loop: extract from each of `plugins/tce/commands/{init,research,plan,work,quickfix,refresh,ticket}.md plugins/tmt/commands/{init,update}.md plugins/tle/commands/define.md plugins/tsf/commands/{init,spec}.md` and `diff` against the first)
- [ ] `claude plugin validate .` and all four `./plugins/*` validations pass
- [ ] `grep -rn 'chat-sustainability\|tobyS\|nono' plugins/tsf/ --include='*.md' --include='*.sh' --include='*.yml' --include='*.json'` finds nothing outside `DESIGN.md` (project-agnostic)

#### Manual Verification:

- [ ] Read `plugins/tsf/README.md` as a new consumer and follow it through init → spec → one cycle in the scratch project without needing DESIGN.md

---

## Testing Strategy

### Unit Tests:

- Script-level checks in a scratch directory (`bash -n`, usage errors, the
  no-credential path, `preflight.sh` with missing scripts and without the
  foreground variable, `tsf_normalize_id` cases). No test framework exists in
  this repo; the criteria are the shell one-liners listed per phase.
- Markdown-contract checks: frontmatter greps, the AskUserQuestion twelve-way
  diff, `cycle.md` size, reference-read phrasing counts, the label-name loop.

### Integration Tests:

- **Scratch GitHub repository** (needed from Phase 2 on): a throwaway repo
  under the user's account with a `main` branch, one open PR, one issue with
  only `tsf:priority`, one with `tsf:queued`, and a **second GitHub account**
  (the factory identity) added as a write collaborator; its PAT (`repo` +
  `workflow`) exported as `GH_TOKEN` in the shell used for script tests and
  for the factory clone. The human's account is the responder.
- The scratch **project**: a tiny repo with the five contract scripts from
  the skeletons (`verify.sh` edited to `exit 0` for the smoke test), the
  plugin installed via `/plugin marketplace add <this repo>` +
  `/plugin install tsf@toby-plugins`.

### Manual Testing Steps:

1. Human working copy: `/tsf:init` (env credential source, responders = the
   human, workflow installed and pushed to `main`), commit the config,
   allowlist and workflow.
2. `/tsf:spec` for a small change; release with `tsf:queued`.
3. Factory clone: `export CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 GH_TOKEN=<factory PAT>`,
   `claude` in the clone, `/tsf:cycle` once (research), then `/loop /tsf:cycle`
   until the issue carries `tsf:needs-plan-approval` and a summary comment
   by the factory account.
4. Reply with feedback on the issue → label flips to `tsf:answered` via the
   workflow → next cycle revises and re-summarizes.
5. Reply `approved` → next cycle sets `tsf:implement`; the following cycle
   reports it as not implemented in this slice and idles.
6. Repeat 3–5 with the workflow file removed and `Comment pickup: polling`.
7. Raw-issue path: label a plain issue `tsf:queued` → triage → questions →
   reply → folded spec → research.
8. Failure paths: start the clone session without the foreground variable
   (cycle refuses); set a wrong `GH_TOKEN` (`identity: mismatch`, no write);
   put `tsf:needs-plan-approval` on an issue without a plan (parked
   `tsf:needs-human` with a mismatch entry); remove `tsf:needs-human`, add
   `tsf:queued` (resumes at the journal's `Next step`).

## Performance Considerations

- REST budget per cycle: preflight (1 call), scan (1 page per 100 issues, plus
  one per parked ticket under polling), reads for the picked ticket (1–2),
  writes (marker, comment, label: 3 calls + 3 read-backs). Well inside 5,000
  requests/hour.
- `cycle.md` under 5,000 tokens keeps the runner's re-attached body intact
  through compaction; everything long is a point-of-use reference.

## Migration Notes

- Nothing consumes tsf yet; the marketplace change is additive. Consumers see
  tsf appear after `/plugin marketplace update toby-plugins`.
- The epic precondition: merge `tsf-design` into `main` before Phase 1; this
  plan document is committed on `tsf-design` and travels with the merge.
- `/tsf:init`'s upgrade list starts at `0.1.0 — nothing to migrate`; slice 2
  (`0.2.0`) extends it if `config.md` gains required fields.

## References

- Original ticket: `thoughts/shared/tickets/TP-0034a-tsf-foundation-human-gates.md`
- Epic: `thoughts/shared/tickets/TP-0034-implement-tsf-plugin-v1.md`
- Research: `thoughts/shared/research/2026-09-16-TP-0034a-tsf-foundation-human-gates.md`
  (slice research) and `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md`
  (epic research; `gh`-porcelain sections superseded)
- Binding design: `plugins/tsf/DESIGN.md` v1.4 — §3, §4 rows 1–4 and 13,
  §5, §6.1–6.5, §8, §10, §11.1, §11.3, §11.4, §12
- Precedents: `plugins/tle/commands/run.md:10-18,95-116` (dispatcher shape),
  `plugins/tce/commands/init.md:13-14,63-70,201-229,369-386,526-553` (init
  shape), `plugins/tce/scripts/branch.sh:29-36,81-86` (report contract),
  `plugins/tce/agents/plan-compliance-checker.md:28-35,73-99` (envelope),
  `thoughts/shared/plans/2026-08-19-TP-0025-tle-loop-engineering-plugin.md`
  (whole-plugin build)
