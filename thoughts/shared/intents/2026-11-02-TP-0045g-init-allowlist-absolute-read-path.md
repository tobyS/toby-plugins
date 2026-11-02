---
date: 2026-11-02
ticket: TP-0045g
ticket_ref: thoughts/shared/tickets/TP-0045g-init-allowlist-absolute-read-path.md
size: Small
status: agreed
last_updated: 2026-11-02
---

# Intent: /tce:init writes a Read grant for a directory-sourced tce that actually matches

## Ticket

TP-0045g (`thoughts/shared/tickets/TP-0045g-init-allowlist-absolute-read-path.md`),
sub-ticket of the TP-0045 epic. The ticket is the human's; this file is the
agreement on what it means here.

## Scope

**In:**
- `plugins/tce/commands/init.md` Phase 4 item 6 ("Allowlist") instructs
  `Read(//<absolute path>/**)` for a tce loaded from its source directory
  (directory-sourced marketplace or `--plugin-dir`), with a one-line reason:
  a single leading `/` is project-relative in Claude Code's permission syntax.
- A `/tce:init` re-run in a project holding only the single-slash entry offers
  the double-slash entry as missing.
- `plugins/tce/README.md`'s allowlist and headless notes agree with the new form.
- tce version bump (patch on 1.7.0); the human tags outside the sandbox.

**Out:**
- The marketplace-install grant `Read(~/.claude/plugins/**)`.
- Untrusted-folder behaviour under `claude -p` (already documented in the
  README by TP-0045e).
- tsf's `/tsf:init` allowlist (writes only `Read(~/.claude/plugins/**)`).
- This repository's own `.claude/settings.json` (holds no `Read(` grant).

## Observable outcome

In a trusted scratch project using a `--plugin-dir` tce, after accepting the
allowlist `/tce:init` offers, a step agent's read of a file under
`<tce>/references/` is allowed with no prompt interactively and no denial under
`claude -p`.

## Anchors

- `plugins/tce/commands/init.md` Phase 4 item 6 "Allowlist" — the "tce's own
  files" bullet ending "with the absolute path written out".
- `plugins/tce/commands/init.md` `## Idempotency` — the tce 1.4.0 bullet that
  recomputes the allowlist and offers missing entries on every re-run.
- `plugins/tce/README.md` — "Accept the allowlist `/tce:init` offers." and
  "Headless runs (`claude -p`)." paragraphs.
- `thoughts/shared/plans/2026-10-27-TP-0045e-defects-from-stage-2-run.md` —
  phase 5's implementation log, the evidence that only `Read(//abs/**)` matched
  (Claude Code 2.1.310).

## Acceptance criteria

- [ ] For a directory-sourced tce, `init.md` instructs `Read(//<absolute path>/**)`
      and states in one sentence why (single `/` is project-relative).
- [ ] Re-run: with only `Read(/<path>/**)` in `permissions.allow`, `/tce:init`
      lists `Read(//<path>/**)` as a missing entry and offers it through the
      existing allowlist dialog.
- [ ] The handling of the stale single-slash entry (left for the user, or its
      removal offered) is decided in planning and stated in `init.md`.
- [ ] Verified on a real run in a trusted scratch project with a `--plugin-dir`
      tce: the written grant allows an agent's reference read — no prompt
      interactively, no denial under `claude -p`; the Claude Code version is
      recorded.
- [ ] `plugins/tce/README.md`'s allowlist and headless notes agree with
      `init.md`.
- [ ] tce version bumped in `plugin.json` and `marketplace.json`; the tag
      command handed to the human (CLAUDE.md "Releasing").

## Decisions

- **Use the `//<absolute path>/**` form** — over a `~/`-relative form: `~/`
  only covers a tce under the home directory, and only `//` was verified on a
  real run.
- **Rely on the existing every-re-run allowlist check for upgrades** — over a
  separate version-gated migration step: the 1.4.0 Idempotency bullet already
  offers whatever is missing regardless of version (to be confirmed by
  research).

## Open questions

None.

## Questions for research

- [ ] Does the 1.4.0 Idempotency bullet cover this case as-is, or does the
      upgrade list need its own entry?
- [ ] Does any other shipped text (README, `check-init.sh`, tsf) write a
      single-slash absolute permission path? (A first grep found none.)
- [ ] Leave the stale single-slash entry, or offer its removal? Removal would be
      a new kind of `settings.json` edit — weigh against CLAUDE.md's
      sanctioned-edit rule ("never widen it").

## Notes

Size Small: a one-rule change in one dialog step plus re-run handling, a README
sentence and a patch release. Marketplace installs are unaffected.
