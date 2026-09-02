#!/bin/bash

# Resolve a usable diff baseline from a commit SHA recorded in a thoughts
# document, falling back to the commit that introduced that document into the
# current history when the recorded SHA is not reachable from HEAD.
# Usage: baseline.sh <recorded-sha> [<document-path>]
#
# Why a recorded SHA can stop being usable: a squash or rebase merge rewrites
# history, so commits made on a feature branch are not ancestors of the commit
# that lands on the main branch. Reachability, not object existence, is the
# test -- after the branch is deleted the objects usually survive locally as
# dangling commits for weeks (the reflog keeps them), so an existence check
# would pass on the machine that made the branch and fail only in a fresh
# clone or in CI.
#
# Prints exactly three lines:
#   baseline: <sha>          (empty when nothing could be resolved)
#   source:   recorded | introducing | none
#   detail:   <one-line explanation the caller can report to the user>
#
# The project root is resolved from the project (see lib.sh), not from this
# script's location -- it ships inside the tce plugin.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

if [ -z "$1" ] && [ -z "$2" ]; then
    echo "Usage: $0 <recorded-sha> [<document-path>]"
    echo "Example: $0 a1b2c3d thoughts/shared/research/2026-01-01-X-0001-topic.md"
    exit 1
fi

RECORDED="$1"
DOC="$2"

cd "$(tce_project_root)"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not a git repository at $(tce_project_root)" >&2
    exit 1
fi

report() {
    printf 'baseline: %s\n' "$1"
    printf 'source:   %s\n' "$2"
    printf 'detail:   %s\n' "$3"
    exit 0
}

SHALLOW_NOTE=""
if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
    SHALLOW_NOTE=" (shallow clone, so history lookups may be incomplete)"
fi

# 1. Prefer the recorded commit, but only if it is in the current history.
if [ -n "$RECORDED" ]; then
    if git merge-base --is-ancestor "$RECORDED" HEAD >/dev/null 2>&1; then
        report "$RECORDED" "recorded" "the recorded commit is in the current history"
    fi
    if git rev-parse --verify --quiet "${RECORDED}^{commit}" >/dev/null 2>&1; then
        WHY="the recorded commit exists locally but is not an ancestor of HEAD, so history was rewritten (e.g. a squash or rebase merge)"
    else
        WHY="the recorded commit is unknown in this clone, so history was rewritten and the original branch is gone${SHALLOW_NOTE}"
    fi
else
    WHY="no commit was recorded"
fi

# 2. Fall back to the commit that introduced the document into this history.
if [ -n "$DOC" ]; then
    INTRODUCING="$(git log --first-parent --diff-filter=A --max-count=1 \
        --format=%H -- "$DOC" 2>/dev/null || true)"
    if [ -z "$INTRODUCING" ]; then
        # Path-limiting disables rename detection, so a renamed document shows
        # up as an add of the new path; --follow walks past the rename.
        INTRODUCING="$(git log --follow --diff-filter=A --max-count=1 \
            --format=%H -- "$DOC" 2>/dev/null || true)"
    fi
    if [ -z "$INTRODUCING" ]; then
        INTRODUCING="$(git rev-list HEAD -- "$DOC" 2>/dev/null | tail -1 || true)"
    fi
    if [ -n "$INTRODUCING" ]; then
        report "$INTRODUCING" "introducing" \
            "$WHY; using the commit that introduced $DOC into the current history"
    fi
    report "" "none" \
        "$WHY, and $DOC has no commit in the current history${SHALLOW_NOTE}"
fi

report "" "none" "$WHY, and no document path was given to fall back on"
