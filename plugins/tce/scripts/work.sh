#!/bin/bash

# The two mechanical checks the orchestrating /tce:work makes. Nothing else
# about a run is checked by a script: agent returns and agent-authored
# documents are read by the orchestrator as text, never parsed here.
#
# Usage:
#   work.sh preflight
#       Is the session set up for foreground dispatch? /tce:work needs each
#       agent's result inside its own turn, and a Bash command that reaches
#       its timeout under CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 is stopped.
#       Prints exactly three lines:
#         foreground: ok | missing
#         timeout:    ok | low (<value or unset>)
#         detail:     <one line the caller can show the user>
#
#   work.sh artifact <path>
#       Did a step leave its document behind? Prints exactly three lines:
#         exists:    yes | no
#         nonempty:  yes | no
#         committed: yes | no
#       "committed" means git tracks the path and it has no uncommitted
#       changes.
#
# Both modes exit 0 on every reported outcome; a usage error exits 2.
#
# The project root is resolved from the project (see lib.sh), not from this
# script's location -- it ships inside the tce plugin.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# The floor tsf's preflight enforces: a real suite outlives the 2-minute
# default, and Claude Code's maximum is 10 minutes unless raised.
TIMEOUT_FLOOR=600000

usage() {
    echo "Usage: $0 preflight" >&2
    echo "       $0 artifact <path>" >&2
    exit 2
}

preflight() {
    local fg timeout detail value
    if [ "${CLAUDE_CODE_DISABLE_BACKGROUND_TASKS:-}" = "1" ]; then
        fg="ok"
    else
        fg="missing"
    fi
    value="${BASH_DEFAULT_TIMEOUT_MS:-}"
    if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge "$TIMEOUT_FLOOR" ]; then
        timeout="ok"
    else
        timeout="low (${value:-unset})"
    fi
    if [ "$fg" = "ok" ] && [ "$timeout" = "ok" ]; then
        detail="foreground dispatch and a ${value} ms Bash timeout are set"
    else
        detail="start Claude Code with CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 and BASH_DEFAULT_TIMEOUT_MS=${TIMEOUT_FLOOR} exported"
    fi
    printf 'foreground: %s\n' "$fg"
    printf 'timeout:    %s\n' "$timeout"
    printf 'detail:     %s\n' "$detail"
    exit 0
}

artifact() {
    local path="$1" exists="no" nonempty="no" committed="no"
    cd "$(tce_project_root)"
    if [ -e "$path" ]; then
        exists="yes"
        if [ -s "$path" ]; then
            nonempty="yes"
        fi
        if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1 \
            && [ -z "$(git status --porcelain -- "$path" 2>/dev/null)" ]; then
            committed="yes"
        fi
    fi
    printf 'exists:    %s\n' "$exists"
    printf 'nonempty:  %s\n' "$nonempty"
    printf 'committed: %s\n' "$committed"
    exit 0
}

case "${1:-}" in
    preflight)
        [ $# -eq 1 ] || usage
        preflight
        ;;
    artifact)
        [ $# -eq 2 ] && [ -n "$2" ] || usage
        artifact "$2"
        ;;
    *)
        usage
        ;;
esac
