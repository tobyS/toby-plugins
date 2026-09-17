#!/bin/bash

# tsf environment contract: prepare (mandatory)
#
# Usage: prepare.sh <branch> <base-branch>
#
# Put the factory's checkout into a pristine state for <branch>: discard every
# local change and untracked file the factory left behind (ignored files, which
# hold environment state, stay), fetch, check out <branch>, and prune local
# branches whose upstream was deleted after a merge. If <branch> does not exist
# on the remote yet, create it locally from <base-branch> -- this is how a
# triaged ticket gets its branch; /tsf:cycle pushes it with the first commit.
# /tsf:cycle calls it at the start of every cycle for the ticket branch, and
# with the base branch as both arguments when nothing is actionable.
#
# This skeleton was copied by /tsf:init and is now yours: adapt the remote name
# or add project steps (submodules, generated files). It only ever runs in the
# factory's own dedicated checkout. This is the project's one sanctioned hard
# reset -- keep your deny rules for ad-hoc `git reset --hard` / `git clean` in
# place for every session.
#
# Exit 0 when the checkout is ready; non-zero otherwise.

set -e

BRANCH="${1:?usage: prepare.sh <branch> <base-branch>}"
BASE="${2:?usage: prepare.sh <branch> <base-branch>}"
REMOTE=origin

git reset --hard --quiet
git clean -fd --quiet
git fetch --prune --quiet "$REMOTE"

if git show-ref --verify --quiet "refs/remotes/$REMOTE/$BRANCH"; then
    git checkout --quiet -B "$BRANCH" "$REMOTE/$BRANCH"
else
    git checkout --quiet -B "$BRANCH" --no-track "$REMOTE/$BASE"
fi

git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
    | awk '$2 == "[gone]" { print $1 }' \
    | while read -r GONE; do
        [ "$GONE" = "$BRANCH" ] || git branch -D --quiet "$GONE"
    done
