# Dossier: TP-0045f — ticketless runs follow the branch convention and delivery

## Summary

tce 1.6.0 lets ticketless runs (`/tce:quickfix`, and any step command or `/tce:work` given an intent path) follow the profile's Branch convention and Delivery exactly as ticket runs do: under Branch per ticket they work on a branch named with the intent's slug, and under Pull request `/tce:quickfix` and `/tce:work` push it and open a pull request.

Criteria met 31/35 · fix rounds 1 · tests added 0 · decisions made for you 13 · for you to check 2

**Start here:** One path deliberately skips the base-branch dialog. A ticketless intent written before 1.6.0 has no branch, so the loop cuts one from the *local* base with `--trust-local` and no fetch, and prints one line instead of asking. Check that this meets intent criterion 3 ("never cuts the branch from a stale base silently"). [`plugins/tce/references/work-loop.md:138-148`](https://github.com/tobyS/toby-plugins/blob/ccd032323277e43a24a138a4fb7372551cde9eec/plugins/tce/references/work-loop.md#L138-L148)

## What was built

The ticketless overrides were removed from `work-loop.md` (Step 2's "skip this step", Step 10's "always Direct"), so ticketless runs now pass through the same absent-section guards as ticket runs. That guard is what keeps Current branch / Direct projects unchanged. The ticketless branch name is the recorded pattern with the intent's slug in place of `<ticket-id>`, with any `<slug>` element dropped along with one separator. It is stated the same way in `work-loop.md`, `intent.md` and `commit.md`. `/tce:intent` stays the create site for new intents: autonomous mode gained a Branch step between choosing the slug and writing, asks the one verbatim base-branch dialog itself, and returns a new third line, `stopped: <reason>`, which quickfix turns into a fixed stop message. The loop's Entry also accepts an intent path that exists only on its branch, switches by the filename's slug, and reads the intent after the switch. `/tce:quickfix` now grants `branch.sh`, `git push` and `gh pr` and runs Step 10 in full. The pull request title for a ticketless run is the intent's `# Intent:` heading. All of this was run headless in scratch repos with a local bare remote and a recording fake `gh`. The only parts not run are a real GitHub pull request and the tag.

## Where to look

- [`plugins/tce/references/work-loop.md:81-90`](https://github.com/tobyS/toby-plugins/blob/ccd032323277e43a24a138a4fb7372551cde9eec/plugins/tce/references/work-loop.md#L81-L90): the Entry now treats a missing intent file as ticketless under Branch per ticket, and checks the `ticket:` line only after the switch. A path to a *ticket's* intent that is missing from the current checkout is caught late, at the end of Step 2 (lines 150-154), not up front.
- [`plugins/tce/commands/intent.md:436-454`](https://github.com/tobyS/toby-plugins/blob/ccd032323277e43a24a138a4fb7372551cde9eec/plugins/tce/commands/intent.md#L436-L454): autonomous mode is no longer "ask nothing". It checks branch names for uniqueness with `git rev-parse --verify`, may ask the base-branch dialog, and has the new `stopped:` return. Headless runs had no AskUserQuestion, so the dialog was observed rendered as prose. Its wording and options matched, but the real dialog was not seen.
- [`plugins/tce/commands/intent.md:120-145`](https://github.com/tobyS/toby-plugins/blob/ccd032323277e43a24a138a4fb7372551cde9eec/plugins/tce/commands/intent.md#L120-L145): the reading rule for case (b), a ticketless intent path that is not on the checkout, was missing from the plan and was added during implementation (ticket from the filename, otherwise the slug, read after the branch step).
- [`plugins/tce/commands/quickfix.md:5`](https://github.com/tobyS/toby-plugins/blob/ccd032323277e43a24a138a4fb7372551cde9eec/plugins/tce/commands/quickfix.md#L5): quickfix is now the second command allowed to push and run `gh pr`. CLAUDE.md's orchestrator rule was widened to match.

## Decided for you

- **The old-intent branch is cut from the local base (`--trust-local`), with a printed line saying so** — over the freshly fetched remote base: an intent committed on the local base but never pushed would be missing from a branch cut from the remote, and "the base that now includes the intent" is the local one.
- **Autonomous mode asks the existing verbatim base-branch dialog itself** — over returning a new line for quickfix to ask: the intent's acceptance criterion says "stops and asks exactly as a ticket run does", the dialog keeps one copy, and the call runs in quickfix's turn.
- **Autonomous mode gets a third return line, `stopped: <reason>`, for a branch step that ends the run (Stop here, dirty tree, invalid name, missing base, blocked)** — over reusing `insufficient:`: the description was sufficient, and quickfix's stop message must say what actually happened.
- **The autonomous slug must also be unused as a branch name** (local branch and `<remote>`'s remote-tracking ref, via `git rev-parse --verify --quiet`) — over relying on the `thoughts/` glob only: `branch.sh create` would silently resume an unmerged ticketless branch of the same name.
- **For interactive ticketless input, the slug is chosen before the branch step and the existing-intent lookup runs after it** — over keeping today's order: the branch needs the slug, and an earlier intent with that slug lives on that branch, so the lookup finds it only after the switch.
- **The loop's Entry accepts an intent path that is not on the current checkout, under Branch per ticket only: it treats it as ticketless, switches by the filename's slug in Step 2, and reads the intent after the switch** — over requiring the session to be on the branch first: a re-run from the base branch (the normal case after `/tce:quickfix` stops) would otherwise refuse.
- **The ticketless pull-request title is the intent's `# Intent:` heading text** — over the slug or the dossier heading: it is the human-readable name the intent was agreed under.
- **`/tce:quickfix` grants `branch.sh`, `git push`, `gh pr create` and `gh pr view` in its own `allowed-tools`** — over relying on `intent.md`'s grant during the Skill call: Skill-call grant scoping is undocumented, and Step 10 runs in quickfix's own turn.
- **The quickfix lane runs Step 10 in full, not in its *no delivery* variant** — over keeping *no delivery* and leaving `undelivered:` for `/tce:work`: follows from your Pull request decision; under Direct both give the same `direct:` reference.
- **The stale "`/tce:research` creates the branch" lines in the profile template and README are corrected to `/tce:intent` while those paragraphs are rewritten** — over leaving them: they sit in the same sentences this ticket rewrites.
- **No `init.md` Idempotency bullet for 1.6.0** — over adding one: no config content changes; only template prose does, and nothing reads that prose to decide behaviour.
- **Version 1.6.0** — over 1.5.2: a behaviour change for Branch per ticket and Pull request projects, not a fix.
- **Not in scope: `/tce:review` and its stale `missing` text** — over fixing it here: it takes ticket references only and is not a ticketless run.

## For you to check

- [ ] Real pull request on GitHub (criterion 34) — in a scratch GitHub repository whose profile has Branch per ticket (`<ticket-id>-<slug>`, base `main`, remote `origin`) and Pull request delivery, with `gh auth status` green, run `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 BASH_DEFAULT_TIMEOUT_MS=600000 claude --plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce` and `/tce:quickfix "<small fix>"`; pass looks like an open pull request from `<slug>` into `main`, titled with the intent's `# Intent:` text and with the dossier as its body (`gh pr view <slug> --json title,body,state`). The push, title, head/base and body file were all observed against a local bare remote and a fake `gh`. Only a real repository and credentials were missing.
- [ ] Tag tce 1.6.0 (criteria 5, 12, 35) — the bump commit `6672861` is not HEAD, so outside the sandbox run `git tag -s tce--v1.6.0 6672861 -m "tce 1.6.0"`, then `git tag --list 'tce--v1.6.0'` (prints the tag) and `git tag -v tce--v1.6.0` (good signature). Signing needs your personal key, which the sandbox denies.

## Concerns

- Permalinks point at a commit on `main`, which is ahead of `origin/main`; they resolve once you push.
- The GitHub branch-name length limit (about 255 bytes) comes only from secondhand sources and is marked unverified in the research.
- Criterion 8 / intent criterion 3: whether cutting a pre-1.6.0 ticketless intent's branch from the local base, without a fetch or the dialog, satisfies "never cuts the branch from a stale base silently" (`work-loop.md:138-148`). It prints one line and does not ask.
- Plan gap resolved in place: `intent.md` class (b) with a ticketless intent not on the checkout had no reading rule; added "ticket from the filename, otherwise the slug, read after the branch step".
- The tag dry-run passes only after the commit, so it was run then and its box ticked in the log commit.
- CLAUDE.md's intent section: "one `create` site" was reworded to "the `create` site for new intents", matching phase 1's old-intent create in the loop.
- Item 34 (real GitHub pull request via `/tce:quickfix` under Pull request delivery) needs a scratch GitHub repo and `gh` credentials — see For you to check.
- Items 5/12/35: the signed tag `tce--v1.6.0` on `6672861` must be created and verified outside the sandbox — see For you to check.

## Artifacts

- Intent: `thoughts/shared/intents/2026-10-27-TP-0045f-ticketless-branch-and-delivery.md`
- Research: `thoughts/shared/research/2026-10-28-TP-0045f-ticketless-branch-and-delivery.md`
- Plan: `thoughts/shared/plans/2026-10-28-TP-0045f-ticketless-branch-and-delivery.md` (its `## Verification` section holds the evidence per criterion)
