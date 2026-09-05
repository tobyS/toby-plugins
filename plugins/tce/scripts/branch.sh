#!/bin/bash

# Put a ticket's branch in place per the project's `## Branch convention`
# (branch-per-ticket projects only -- the calling command decides whether the
# convention applies and resolves the branch name; this script does the git).
#
# Usage: branch.sh create <branch> <base> [<remote>] [--trust-local]
#        branch.sh switch <branch>
#        branch.sh check  <branch> <base>
#
#   create  -- for /tce:research: switch to <branch> if it already exists
#              (locally or on <remote>); otherwise fetch <base> from <remote>
#              and create <branch> from the fetched tip. If the fetch fails or
#              there is no remote, nothing is created: the caller must ask the
#              user, and re-run with --trust-local only once the user confirmed
#              that the local <base> tip is current. Never cuts the branch from
#              anything but <remote>/<base> (or, trusted, the local <base>).
#   switch  -- for /tce:plan, /tce:implement, /tce:review: switch to an existing
#              <branch>; never creates one.
#   check   -- for /tce:commit: report where HEAD is; no side effects.
#
# create and switch refuse to move a working tree with uncommitted tracked
# changes (result: dirty) -- untracked files carry over harmlessly and are
# ignored. A branch that already is the current branch is always fine.
#
# Prints exactly three lines:
#   branch:  <current branch after the command ran; empty on detached HEAD>
#   result:  create: created | switched | already | fetch-failed | no-remote |
#                    missing-base | dirty | blocked | invalid-name
#            switch: switched | already | missing | dirty | blocked
#            check:  on-branch | on-base | elsewhere | detached
#   detail:  <one-line explanation the caller can report to the user>
#
# Every reported outcome exits 0; only usage errors and "not a git repository"
# exit 1. The project root is resolved from the project (see lib.sh), not from
# this script's location -- it ships inside the tce plugin.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Usage: $0 create <branch> <base> [<remote>] [--trust-local]"
    echo "       $0 switch <branch>"
    echo "       $0 check  <branch> <base>"
    echo "Example: $0 create MYAPP-0042 main origin"
    exit 1
}

MODE="${1:-}"
[ -n "$MODE" ] || usage
shift
TRUST_LOCAL=0
POSITIONAL=()
for ARG in "$@"; do
    case "$ARG" in
        --trust-local) TRUST_LOCAL=1 ;;
        *) POSITIONAL+=("$ARG") ;;
    esac
done
BRANCH="${POSITIONAL[0]:-}"
BASE="${POSITIONAL[1]:-}"
REMOTE="${POSITIONAL[2]:-}"

case "$MODE" in
    create) { [ -n "$BRANCH" ] && [ -n "$BASE" ]; } || usage ;;
    switch) [ -n "$BRANCH" ] || usage ;;
    check)  { [ -n "$BRANCH" ] && [ -n "$BASE" ]; } || usage ;;
    *) usage ;;
esac

cd "$(tce_project_root)"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not a git repository at $(tce_project_root)" >&2
    exit 1
fi

report() {
    printf 'branch:  %s\n' "$(git branch --show-current 2>/dev/null || true)"
    printf 'result:  %s\n' "$1"
    printf 'detail:  %s\n' "$2"
    exit 0
}

CURRENT="$(git branch --show-current 2>/dev/null || true)"

local_exists()  { git show-ref --verify --quiet "refs/heads/$1"; }
remote_exists() { [ -n "$REMOTE" ] && git show-ref --verify --quiet "refs/remotes/$REMOTE/$1"; }
tree_dirty()    { [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; }

# Switch to an existing local branch, or to a remote-tracking one (git creates
# the local tracking branch). Reports and exits.
switch_existing() {
    if tree_dirty; then
        report "dirty" "the working tree has uncommitted changes; commit or stash them before switching to $BRANCH"
    fi
    if OUT="$(git switch "$BRANCH" 2>&1)"; then
        report "switched" "switched to $BRANCH"
    fi
    report "blocked" "git could not switch to $BRANCH: $(printf '%s' "$OUT" | tail -1)"
}

case "$MODE" in

check)
    if [ -z "$CURRENT" ]; then
        report "detached" "HEAD is detached, not on $BRANCH"
    elif [ "$CURRENT" = "$BRANCH" ]; then
        report "on-branch" "on the ticket branch $BRANCH"
    elif [ "$CURRENT" = "$BASE" ]; then
        report "on-base" "on the base branch $BASE, not on the ticket branch $BRANCH"
    fi
    report "elsewhere" "on $CURRENT, neither the ticket branch $BRANCH nor the base branch $BASE"
    ;;

switch)
    if [ "$CURRENT" = "$BRANCH" ]; then
        report "already" "already on $BRANCH"
    fi
    if local_exists "$BRANCH" || [ -n "$(git for-each-ref "refs/remotes/*/$BRANCH" 2>/dev/null)" ]; then
        switch_existing
    fi
    report "missing" "branch $BRANCH does not exist; /tce:research creates it"
    ;;

create)
    if [ "$CURRENT" = "$BRANCH" ]; then
        report "already" "already on $BRANCH"
    fi
    if ! git check-ref-format --branch "$BRANCH" >/dev/null 2>&1; then
        report "invalid-name" "$BRANCH is not a valid git branch name; check the pattern in the profile's Branch convention"
    fi
    if local_exists "$BRANCH" || remote_exists "$BRANCH"; then
        switch_existing
    fi
    if tree_dirty; then
        report "dirty" "the working tree has uncommitted changes; commit or stash them before creating $BRANCH"
    fi
    if [ "$TRUST_LOCAL" = "1" ]; then
        if ! local_exists "$BASE"; then
            report "missing-base" "the base branch $BASE does not exist locally"
        fi
        if OUT="$(git switch -c "$BRANCH" --no-track "$BASE" 2>&1)"; then
            report "created" "created $BRANCH from the local $BASE tip $(git rev-parse --short HEAD) (trusted as current)"
        fi
        report "blocked" "git could not create $BRANCH: $(printf '%s' "$OUT" | tail -1)"
    fi
    if [ -z "$REMOTE" ] || [ "$REMOTE" = "none" ]; then
        report "no-remote" "no remote is configured for $BASE, so it cannot be brought up to date; confirm the local $BASE tip is current, then re-run with --trust-local"
    fi
    if ! OUT="$(GIT_HTTP_LOW_SPEED_LIMIT=1000 GIT_HTTP_LOW_SPEED_TIME=20 \
            git fetch "$REMOTE" "$BASE" 2>&1)"; then
        report "fetch-failed" "could not fetch $BASE from $REMOTE ($(printf '%s' "$OUT" | tail -1)); update it or confirm the local $BASE tip is current, then re-run with --trust-local"
    fi
    if OUT="$(git switch -c "$BRANCH" --no-track "$REMOTE/$BASE" 2>&1)"; then
        report "created" "created $BRANCH from $REMOTE/$BASE at $(git rev-parse --short HEAD)"
    fi
    report "blocked" "git could not create $BRANCH: $(printf '%s' "$OUT" | tail -1)"
    ;;
esac
