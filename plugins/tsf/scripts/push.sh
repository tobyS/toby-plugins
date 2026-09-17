#!/bin/bash

# The one push path (DESIGN.md §12). Invoked by /tsf:cycle's write phase to
# push the ticket branch as the factory identity.
#
# Usage: push.sh --branch B --credential env|proxy [--remote origin]
#
#   env    -- push over https with GH_TOKEN as the credential, resolved
#             explicitly for this one call: every configured credential helper
#             is cleared and a single helper answering with GH_TOKEN is used,
#             so neither the human's keychain entry nor their gh login can
#             stand in. An ssh remote is refused (result: ssh-remote): ssh
#             would authenticate with whatever key the machine holds.
#   proxy  -- plain `git push`: the proxy injects the credential by
#             repository URL.
#
#   Pushes exactly the named branch to the same name on the remote. Never
#   --force, never --force-with-lease, never any other refspec. Runs in the
#   project root (the factory clone).
#
# Prints exactly three lines:
#   branch:    <the branch pushed>
#   result:    pushed | up-to-date | no-credential | ssh-remote | failed
#   detail:    <one line: git's last output line, or the reason>
#
# Every reported outcome exits 0; only usage errors and "not a git repository"
# exit 1.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Error: missing or invalid arguments" >&2
    echo "Usage: $0 --branch B --credential env|proxy [--remote origin]" >&2
    exit 1
}

BRANCH=""; CREDENTIAL=""; REMOTE="origin"
while [ $# -gt 0 ]; do
    case "$1" in
        --branch)     BRANCH="${2:-}"; shift 2 || usage ;;
        --credential) CREDENTIAL="${2:-}"; shift 2 || usage ;;
        --remote)     REMOTE="${2:-}"; shift 2 || usage ;;
        *) usage ;;
    esac
done
[ -n "$BRANCH" ] && [ -n "$REMOTE" ] || usage
case "$CREDENTIAL" in env|proxy) ;; *) usage ;; esac

cd "$(tsf_project_root)"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not a git repository at $(tsf_project_root)" >&2
    exit 1
fi

report() {
    printf 'branch:    %s\n' "$BRANCH"
    printf 'result:    %s\n' "$1"
    printf 'detail:    %s\n' "$2"
    exit 0
}

tsf_tmp
OUT="$TSF_TMP/push.out"
export GIT_TERMINAL_PROMPT=0

if [ "$CREDENTIAL" = "env" ]; then
    tsf_identity factory env || report "no-credential" "credential source env, but GH_TOKEN is not set"
    URL="$(git remote get-url "$REMOTE" 2>/dev/null || true)"
    case "$URL" in
        https://*) ;;
        '') report "failed" "remote $REMOTE is not configured" ;;
        *) report "ssh-remote" "remote $REMOTE is $URL; the env credential source needs an https remote" ;;
    esac
    # shellcheck disable=SC2016
    if git -c credential.helper= \
            -c credential.helper='!f() { echo username=x-access-token; echo "password=$GH_TOKEN"; }; f' \
            push "$REMOTE" "refs/heads/$BRANCH:refs/heads/$BRANCH" >"$OUT" 2>&1; then
        PUSHED=1
    else
        PUSHED=0
    fi
else
    if git push "$REMOTE" "refs/heads/$BRANCH:refs/heads/$BRANCH" >"$OUT" 2>&1; then
        PUSHED=1
    else
        PUSHED=0
    fi
fi

LAST="$(grep -v '^[[:space:]]*$' "$OUT" | tail -1 || true)"
if [ "$PUSHED" = "0" ]; then
    report "failed" "${LAST:-git push failed without output}"
fi
if grep -q 'Everything up-to-date' "$OUT"; then
    report "up-to-date" "$REMOTE/$BRANCH already at $(git rev-parse --short "refs/heads/$BRANCH")"
fi
report "pushed" "pushed $BRANCH to $REMOTE at $(git rev-parse --short "refs/heads/$BRANCH")"
