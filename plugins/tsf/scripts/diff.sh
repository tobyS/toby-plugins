#!/bin/bash

# The git facts DESIGN.md §3.5 defines, computed in the factory's clone.
# Invoked by /tsf:cycle before the gates and when it reads a review.
#
# Usage: diff.sh pr-diff   --base BASE [--out FILE]
#        diff.sh files     --base BASE [--ref REF]
#        diff.sh logic-head
#        diff.sh ancestor  --commit A --of B
#        diff.sh clean
#
#   pr-diff   Write the **PR diff** -- the three-dot diff of the branch against
#             the base branch, `thoughts/` excluded -- to FILE, and a --stat
#             summary to FILE.stat. Three dots means merge-base to head, which
#             is what GitHub's Files tab shows and what stays correct after a
#             sync merge; no base commit is recorded anywhere. The base is
#             resolved as `origin/BASE` when that remote-tracking ref exists
#             (the prepare script fetched it this cycle), else as BASE.
#
#             It is computed locally on purpose: the REST diff is capped at 300
#             files, 20,000 lines and 1 MB, and answers above those limits are
#             not documented. The file is untracked and lives exactly one cycle
#             -- the next prepare run's `git clean -fd` removes it -- and it is
#             never staged: the write phase stages named files only.
#
#               file:      <path to the diff, relative to the project root>
#               stat:      <path to the --stat summary>
#               files:     <number of files in the diff>
#               lines:     <number of lines in the diff>
#               result:    ok | empty | failed
#               detail:    <one line>
#
#   files     The paths a branch changes against the base, three-dot and with
#             `thoughts/` excluded — the same comparison as pr-diff, reduced to
#             names. REF defaults to HEAD; pass `origin/<branch>` to ask about
#             another ticket's branch without checking it out, which is how the
#             dossier step learns which other open factory pull requests touch
#             the same files (§9.1's overlap warning) without a REST call.
#
#               count:     <number of files>
#               result:    ok | none | failed
#               detail:    <one line>
#               files:
#               <one path per line, to the end of the output>
#
#   logic-head  The **logic head** (§3.5): the newest commit that touches a path
#             outside `thoughts/` and is not a **mechanical sync merge**.
#             Journal, report and dossier commits are inert by construction, so
#             a gate report naming this sha stays current until real code moves.
#
#             A commit is a mechanical sync merge when it has two parents AND
#             either
#               (a) GitHub made it -- the server-side update-branch merge of
#                   §9.3 step 1, whose committer is GitHub's web-flow. The
#                   AUTHOR is useless here: it is the identity that called the
#                   endpoint, i.e. the factory itself, indistinguishable from an
#                   ordinary factory commit (verified 2026-09-19), or
#               (b) it carries the trailer  Tsf-Resolution: mechanical  -- a
#                   merge-resolver resolution the agent classified mechanical.
#
#             A resolution carrying  Tsf-Resolution: logic , and a two-parent
#             merge carrying no trailer at all, both COUNT as the logic head:
#             they changed behaviour, so an earlier approval no longer covers
#             the code and the gate reports are stale. Failing closed is
#             deliberate -- the cost is one avoidable re-approval, against
#             silently landing unreviewed logic.
#
#               logic_head: <sha> | -
#               short:      <short sha> | -
#               result:     ok | none | failed
#               detail:     <one line>
#
#   main-delta  What the base branch gained since a point -- the integration
#             gate's second input (§7 gate 4, §9.3 step 2). The start point is
#             either given directly (--from, the main head a previous
#             integration report recorded) or derived (--approval, the approving
#             review's commit_id, whose merge-base with the base branch is where
#             this pull request diverged).
#
#               file:      <path of the patch>
#               stat:      <path of the --stat summary>
#               main_head: <the base branch's head sha>
#               moved:     yes | no
#               files:     <number of files>
#               lines:     <number of lines in the patch>
#               result:    ok | empty | failed
#               detail:    <one line>
#             moved: no (result: empty) means the base branch has not moved and
#             the gate is skipped.
#
#   decision-head  Which commit carries the ticket's latest journal entry, and
#             whether it is still the branch's head (§9.3 steps 4-5). After a
#             landing decision cycle the newest commit touching the journal IS
#             the decision commit -- the merge cycle writes nothing, so nothing
#             newer can touch it. That is how the merge cycle checks "the decided
#             head is still the pull request head" without recording a sha
#             anywhere (§3.5: no base commit is recorded anywhere).
#
#               decision_head: <sha> | -
#               pr_head:       <sha> | -
#               unchanged:     yes | no
#               result:        ok | none | failed
#               detail:        <one line>
#             unchanged: no means something was pushed after the decision: the
#             decision is void and the landing restarts at the sync.
#
#   ancestor  Is commit A reachable from commit B? This is how an approval's
#             validity is judged (§4 row 10: the review's commit_id must be at
#             or after the logic head). Reachability, not mere existence -- a
#             commit can exist in the clone and not be on this branch.
#
#               result:    yes | no | unknown
#               detail:    <one line>
#
#   clean     Remove the temporary directory holding the diff files.
#
#               result:    ok
#
# Every reported outcome exits 0; only usage errors and "not a git repository"
# exit 1.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Error: missing or invalid arguments" >&2
    echo "Usage: $0 pr-diff    --base BASE [--out FILE]" >&2
    echo "       $0 files      --base BASE [--ref REF]" >&2
    echo "       $0 logic-head" >&2
    echo "       $0 main-delta --base BASE (--from SHA | --approval SHA) [--out FILE]" >&2
    echo "       $0 decision-head --journal PATH" >&2
    echo "       $0 ancestor   --commit A --of B" >&2
    echo "       $0 clean" >&2
    exit 1
}

TSF_WORK_DIR=".tsf-tmp"

MODE="${1:-}"
[ -n "$MODE" ] || usage
shift
BASE=""; OUT=""; COMMIT=""; OF=""; REF=""; FROM=""; APPROVAL=""; JOURNAL=""
while [ $# -gt 0 ]; do
    case "$1" in
        --base)     BASE="${2:-}"; shift 2 || usage ;;
        --out)      OUT="${2:-}"; shift 2 || usage ;;
        --commit)   COMMIT="${2:-}"; shift 2 || usage ;;
        --of)       OF="${2:-}"; shift 2 || usage ;;
        --ref)      REF="${2:-}"; shift 2 || usage ;;
        --from)     FROM="${2:-}"; shift 2 || usage ;;
        --approval) APPROVAL="${2:-}"; shift 2 || usage ;;
        --journal)  JOURNAL="${2:-}"; shift 2 || usage ;;
        *) usage ;;
    esac
done
case "$MODE" in
    pr-diff)   [ -n "$BASE" ] || usage ;;
    files)     [ -n "$BASE" ] || usage ;;
    logic-head) ;;
    main-delta) [ -n "$BASE" ] || usage
               # Exactly one start point.
               { [ -n "$FROM" ] && [ -z "$APPROVAL" ]; } \
                   || { [ -z "$FROM" ] && [ -n "$APPROVAL" ]; } || usage ;;
    decision-head) [ -n "$JOURNAL" ] || usage ;;
    ancestor)  { [ -n "$COMMIT" ] && [ -n "$OF" ]; } || usage ;;
    clean)     ;;
    *) usage ;;
esac

cd "$(tsf_project_root)"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not a git repository at $(tsf_project_root)" >&2
    exit 1
fi

case "$MODE" in

pr-diff)
    OUT="${OUT:-$TSF_WORK_DIR/pr-diff.patch}"
    mkdir -p "$(dirname "$OUT")"
    # Prefer the fetched remote-tracking ref: the local base branch may be
    # stale, or may not exist at all in a clone that only ever checks out
    # ticket branches.
    BASE_REF="$BASE"
    if git show-ref --verify --quiet "refs/remotes/origin/$BASE"; then
        BASE_REF="origin/$BASE"
    fi
    if ! git rev-parse --verify --quiet "$BASE_REF" >/dev/null; then
        printf 'result:    %s\n' "failed"
        printf 'detail:    %s\n' "the base branch $BASE does not exist in this checkout"
        exit 0
    fi
    if ! git diff "$BASE_REF...HEAD" -- . ':(exclude)thoughts/' >"$OUT" 2>"$OUT.err"; then
        printf 'result:    %s\n' "failed"
        printf 'detail:    %s\n' "git diff against $BASE_REF failed: $(tail -1 "$OUT.err" 2>/dev/null || true)"
        exit 0
    fi
    git diff "$BASE_REF...HEAD" --stat -- . ':(exclude)thoughts/' >"$OUT.stat" 2>/dev/null || true
    rm -f "$OUT.err"
    FILES="$(grep -c '^diff --git ' "$OUT" || true)"
    LINES="$(wc -l <"$OUT" | tr -d ' ')"
    printf 'file:      %s\n' "$OUT"
    printf 'stat:      %s\n' "$OUT.stat"
    printf 'files:     %s\n' "${FILES:-0}"
    printf 'lines:     %s\n' "$LINES"
    if [ ! -s "$OUT" ]; then
        printf 'result:    %s\n' "empty"
        printf 'detail:    %s\n' "the branch changes nothing outside thoughts/ against $BASE_REF"
        exit 0
    fi
    printf 'result:    %s\n' "ok"
    printf 'detail:    %s\n' "three-dot diff against $BASE_REF, thoughts/ excluded"
    exit 0
    ;;

files)
    REF="${REF:-HEAD}"
    BASE_REF="$BASE"
    if git show-ref --verify --quiet "refs/remotes/origin/$BASE"; then
        BASE_REF="origin/$BASE"
    fi
    if ! git rev-parse --verify --quiet "$BASE_REF" >/dev/null \
            || ! git rev-parse --verify --quiet "$REF" >/dev/null; then
        printf 'count:     %s\n' "0"
        printf 'result:    %s\n' "failed"
        printf 'detail:    %s\n' "$BASE_REF or $REF does not exist in this checkout"
        exit 0
    fi
    tsf_tmp
    git diff "$BASE_REF...$REF" --name-only -- . ':(exclude)thoughts/' >"$TSF_TMP/files.txt" 2>/dev/null || true
    COUNT="$(grep -c . "$TSF_TMP/files.txt" || true)"
    printf 'count:     %s\n' "${COUNT:-0}"
    if [ "${COUNT:-0}" = "0" ]; then
        printf 'result:    %s\n' "none"
        printf 'detail:    %s\n' "$REF changes nothing outside thoughts/ against $BASE_REF"
        exit 0
    fi
    printf 'result:    %s\n' "ok"
    printf 'detail:    %s\n' "files $REF changes against $BASE_REF, thoughts/ excluded"
    printf 'files:\n'
    cat "$TSF_TMP/files.txt"
    exit 0
    ;;

logic-head)
    # Walk the candidates newest-first and skip mechanical sync merges. The
    # first survivor is the logic head. Two parents is the cheap precondition,
    # so the per-commit reads below only ever run on merges.
    #
    # --first-parent is load-bearing, not an optimization: a sync merge makes
    # the base branch's commits reachable from this branch, and without it the
    # newest of THOSE would become the logic head -- which would invalidate the
    # approval on every sync and defeat the exclusion this function exists for.
    # The ticket branch's own line of development is its first-parent chain.
    SHA=""
    while IFS= read -r CANDIDATE; do
        [ -n "$CANDIDATE" ] || continue
        PARENTS="$(git rev-list --parents -n 1 "$CANDIDATE" | wc -w | tr -d ' ')"
        if [ "$PARENTS" -lt 3 ]; then SHA="$CANDIDATE"; break; fi
        COMMITTER_EMAIL="$(git show -s --format='%ce' "$CANDIDATE")"
        COMMITTER_NAME="$(git show -s --format='%cn' "$CANDIDATE")"
        # (a) GitHub's server-side update-branch merge.
        if [ "$COMMITTER_EMAIL" = "noreply@github.com" ] && [ "$COMMITTER_NAME" = "GitHub" ]; then
            continue
        fi
        # (b) A resolution the merge-resolver classified mechanical. Anything
        # else -- logic, or no trailer at all -- counts as the logic head.
        if [ "$(git show -s --format='%(trailers:key=Tsf-Resolution,valueonly,separator=%x2C)' "$CANDIDATE" | tr -d '[:space:]')" = "mechanical" ]; then
            continue
        fi
        SHA="$CANDIDATE"
        break
    done <<EOF
$(git rev-list --first-parent HEAD -- . ':(exclude)thoughts/' 2>/dev/null || true)
EOF
    if [ -z "$SHA" ]; then
        printf 'logic_head: %s\n' "-"
        printf 'short:      %s\n' "-"
        printf 'result:     %s\n' "none"
        printf 'detail:     %s\n' "no commit on this branch touches a path outside thoughts/"
        exit 0
    fi
    printf 'logic_head: %s\n' "$SHA"
    printf 'short:      %s\n' "$(git rev-parse --short "$SHA")"
    printf 'result:     %s\n' "ok"
    printf 'detail:     %s\n' "newest commit touching a path outside thoughts/ that is not a mechanical sync merge"
    exit 0
    ;;

main-delta)
    OUT="${OUT:-$TSF_WORK_DIR/main-delta.patch}"
    mkdir -p "$(dirname "$OUT")"
    BASE_REF="$BASE"
    if git show-ref --verify --quiet "refs/remotes/origin/$BASE"; then
        BASE_REF="origin/$BASE"
    fi
    if ! git rev-parse --verify --quiet "$BASE_REF" >/dev/null; then
        printf 'result:    %s\n' "failed"
        printf 'detail:    %s\n' "the base branch $BASE does not exist in this checkout"
        exit 0
    fi
    MAIN_HEAD="$(git rev-parse "$BASE_REF")"
    if [ -n "$FROM" ]; then
        START="$FROM"
    else
        # The approving review's commit_id is on the ticket branch; where that
        # branch left the base branch is what "since the approval" means.
        START="$(git merge-base "$APPROVAL" "$BASE_REF" 2>/dev/null || true)"
    fi
    if [ -z "$START" ] || ! git rev-parse --verify --quiet "$START^{commit}" >/dev/null; then
        printf 'result:    %s\n' "failed"
        printf 'detail:    %s\n' "the start point ${FROM:-$APPROVAL} is not a commit in this checkout"
        exit 0
    fi
    if ! git diff "$START..$BASE_REF" -- . ':(exclude)thoughts/' >"$OUT" 2>"$OUT.err"; then
        printf 'result:    %s\n' "failed"
        printf 'detail:    %s\n' "git diff $START..$BASE_REF failed: $(tail -1 "$OUT.err" 2>/dev/null || true)"
        exit 0
    fi
    git diff "$START..$BASE_REF" --stat -- . ':(exclude)thoughts/' >"$OUT.stat" 2>/dev/null || true
    rm -f "$OUT.err"
    FILES="$(grep -c '^diff --git ' "$OUT" || true)"
    LINES="$(wc -l <"$OUT" | tr -d ' ')"
    printf 'file:      %s\n' "$OUT"
    printf 'stat:      %s\n' "$OUT.stat"
    printf 'main_head: %s\n' "$MAIN_HEAD"
    printf 'files:     %s\n' "${FILES:-0}"
    printf 'lines:     %s\n' "$LINES"
    if [ ! -s "$OUT" ]; then
        printf 'moved:     %s\n' "no"
        printf 'result:    %s\n' "empty"
        printf 'detail:    %s\n' "$BASE_REF has gained nothing outside thoughts/ since $START"
        exit 0
    fi
    printf 'moved:     %s\n' "yes"
    printf 'result:    %s\n' "ok"
    printf 'detail:    %s\n' "what $BASE_REF gained since $START, thoughts/ excluded"
    exit 0
    ;;

decision-head)
    DECISION="$(git rev-list -1 HEAD -- "$JOURNAL" 2>/dev/null || true)"
    if [ -z "$DECISION" ]; then
        printf 'decision_head: %s\n' "-"
        printf 'pr_head:       %s\n' "$(git rev-parse HEAD)"
        printf 'unchanged:     %s\n' "no"
        printf 'result:        %s\n' "none"
        printf 'detail:        %s\n' "no commit on this branch touches $JOURNAL"
        exit 0
    fi
    PR_HEAD="$(git rev-parse HEAD)"
    printf 'decision_head: %s\n' "$DECISION"
    printf 'pr_head:       %s\n' "$PR_HEAD"
    if [ "$DECISION" = "$PR_HEAD" ]; then
        printf 'unchanged:     %s\n' "yes"
        printf 'result:        %s\n' "ok"
        printf 'detail:        %s\n' "the newest journal commit is still the branch head"
        exit 0
    fi
    printf 'unchanged:     %s\n' "no"
    printf 'result:        %s\n' "ok"
    printf 'detail:        %s\n' "$PR_HEAD was pushed after the newest journal commit $DECISION"
    exit 0
    ;;

ancestor)
    if ! git rev-parse --verify --quiet "$COMMIT^{commit}" >/dev/null \
            || ! git rev-parse --verify --quiet "$OF^{commit}" >/dev/null; then
        printf 'result:    %s\n' "unknown"
        printf 'detail:    %s\n' "one of $COMMIT and $OF is not a commit in this checkout"
        exit 0
    fi
    if git merge-base --is-ancestor "$COMMIT" "$OF"; then
        printf 'result:    %s\n' "yes"
        printf 'detail:    %s\n' "$COMMIT is reachable from $OF"
        exit 0
    fi
    printf 'result:    %s\n' "no"
    printf 'detail:    %s\n' "$COMMIT is not reachable from $OF"
    exit 0
    ;;

clean)
    rm -rf "$TSF_WORK_DIR"
    printf 'result:    %s\n' "ok"
    printf 'detail:    %s\n' "removed $TSF_WORK_DIR"
    exit 0
    ;;
esac
