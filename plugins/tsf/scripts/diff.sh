#!/bin/bash

# The git facts DESIGN.md §3.5 defines, computed in the factory's clone.
# Invoked by /tsf:cycle before the gates and when it reads a review.
#
# Usage: diff.sh pr-diff   --base BASE [--out FILE]
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
#   logic-head  The **logic head**: the newest commit that touches a path
#             outside `thoughts/`. Journal, report and dossier commits are inert
#             by construction, so a gate report naming this sha stays current
#             until real code moves. (Mechanical sync merges, which §3.5 also
#             excludes, do not exist before the landing slice.)
#
#               logic_head: <sha> | -
#               short:      <short sha> | -
#               result:     ok | none | failed
#               detail:     <one line>
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
    echo "       $0 logic-head" >&2
    echo "       $0 ancestor   --commit A --of B" >&2
    echo "       $0 clean" >&2
    exit 1
}

TSF_WORK_DIR=".tsf-tmp"

MODE="${1:-}"
[ -n "$MODE" ] || usage
shift
BASE=""; OUT=""; COMMIT=""; OF=""
while [ $# -gt 0 ]; do
    case "$1" in
        --base)   BASE="${2:-}"; shift 2 || usage ;;
        --out)    OUT="${2:-}"; shift 2 || usage ;;
        --commit) COMMIT="${2:-}"; shift 2 || usage ;;
        --of)     OF="${2:-}"; shift 2 || usage ;;
        *) usage ;;
    esac
done
case "$MODE" in
    pr-diff)   [ -n "$BASE" ] || usage ;;
    logic-head) ;;
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

logic-head)
    SHA="$(git rev-list -1 HEAD -- . ':(exclude)thoughts/' 2>/dev/null || true)"
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
    printf 'detail:     %s\n' "newest commit touching a path outside thoughts/"
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
