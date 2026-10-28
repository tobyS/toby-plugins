# TP-0045g: /tce:init writes an absolute Read grant that never matches

**Status:** Open
**Estimated Complexity:** Small
**Created:** 2026-10-28
**Updated:** 2026-10-28

Sub-ticket of TP-0045 (the epic). A defect, found during TP-0045e's
verification run and recorded there as out of scope.

## Problem Statement

`/tce:init`'s allowlist step (`plugins/tce/commands/init.md`, Phase 4 item 6,
"Allowlist") offers a `Read` grant so the step agents can read tce's reference
files, which lie outside the project directory. For a marketplace install it
offers `Read(~/.claude/plugins/**)`. For a tce loaded from its source directory
(a directory-sourced marketplace or `--plugin-dir`) it offers
`Read(<that path>/**)` "with the absolute path written out" — i.e. a pattern
starting with a single `/`.

In Claude Code's permission syntax a single leading `/` means a path relative
to the settings file's project, not an absolute path; an absolute path needs
`//`. TP-0045e's phase 5 confirmed it on Claude Code 2.1.310: the single-slash
form was denied even in a trusted folder, and only `Read(//<absolute path>/**)`
matched. So in a project whose tce comes from a local directory — this
repository's own consumer projects among them — the grant `/tce:init` writes
never takes effect, and the agents' reference reads prompt (interactive) or are
denied (`claude -p`).

Marketplace installs are unaffected (`~/` is handled correctly).

## Desired Outcome

`/tce:init` offers a `Read` grant for a directory-sourced tce that actually
matches the reference reads, and a project that already holds the broken entry
gets the corrected one offered on re-run.

## Acceptance Criteria

- [ ] For a directory-sourced tce, `init.md` instructs the `Read(//<absolute path>/**)`
      form (or another form verified to match), and says why.
- [ ] `/tce:init`'s re-run detects an existing single-slash entry for tce's
      path as missing and offers the corrected one (the old entry is left for
      the user to remove, or its removal is offered — decided in planning).
- [ ] Verified on a real run: an agent's read of a reference file under a
      `--plugin-dir` tce is allowed by the written grant, with no prompt
      interactively and no denial under `claude -p`, in a trusted folder.
- [ ] The tce README's allowlist / headless notes agree with the new form.
- [ ] tce version bumped; the human tags it outside the sandbox (CLAUDE.md
      "Releasing").

## Out of Scope

- The marketplace-install grant `Read(~/.claude/plugins/**)`.
- The untrusted-folder behaviour under `claude -p` (already documented in the
  README's "Headless runs" note by TP-0045e).
- tsf's `/tsf:init` allowlist (`Read(~/.claude/plugins/**)` only).

## Open Questions

None at this time.

## Questions for Research/Planning

- [ ] Whether `/tce:init`'s Idempotency upgrade list needs an entry for
      projects initialised with the broken grant.
- [ ] Whether any other shipped text (README, `check-init.sh`, tsf) writes a
      single-slash absolute permission path.

## References

- `plugins/tce/commands/init.md` — Phase 4 item 6, "Allowlist"
- `thoughts/shared/dossiers/2026-10-27-TP-0045e-defects-from-stage-2-run.md`
  — Concerns, where the defect was recorded
- `thoughts/shared/plans/2026-10-27-TP-0045e-defects-from-stage-2-run.md` —
  phase 5's implementation log, the evidence

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-10-28

- Filed from TP-0045e's verification concerns as a sub-ticket of the epic.
