#!/bin/bash

# The two mechanical checks the orchestrating step commands make. Nothing else
# about a run is checked by a script: agent returns and agent-authored
# documents are read by the orchestrator as text, never parsed here.
#
# Usage:
#   work.sh preflight
#       Is the session set up for foreground dispatch? A step command needs
#       each agent's result inside its own turn, and a Bash command that
#       reaches its timeout under CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 is
#       stopped. Is the project's profile older than this plugin?
#       Prints exactly four lines:
#         foreground: ok | missing
#         timeout:    ok | low (<value or unset>)
#         profile:    ok | older <profile version> <plugin version>
#         detail:     <one line the caller can show the user>
#       Anything that cannot be compared (no marker, the template's
#       placeholder, a missing file, a marker newer than the plugin) reports
#       "ok" on the profile line.
#       When both environment checks are ok and the profile is older, the
#       four lines are followed by the warning itself and the instruction to
#       print it: the words reach the model in the result it has to act on,
#       which real runs followed where a rule read earlier was not.
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

# Is the project's profile older than this plugin? Prints "ok" or
# "older <profile version> <plugin version>". Anything that cannot be compared
# (no marker, the template's placeholder, a missing file) is "ok".
profile_state() {
    local profile manifest line i pv vv
    local -a p v
    local version='([0-9]+)\.([0-9]+)\.([0-9]+)'
    local marker_re="^<!-- tce-config-version: ${version} -->[[:space:]]*$"
    local manifest_re="\"version\"[[:space:]]*:[[:space:]]*\"${version}\""
    profile="$(tce_project_root)/.claude/tce/profile.md"
    manifest="$SCRIPT_DIR/../.claude-plugin/plugin.json"
    if [ ! -r "$profile" ] || [ ! -r "$manifest" ]; then
        echo ok
        return 0
    fi
    line=""
    IFS= read -r line < "$profile" || true
    if ! [[ "$line" =~ $marker_re ]]; then
        echo ok
        return 0
    fi
    p=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}")
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ $manifest_re ]]; then
            v=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}")
            break
        fi
    done < "$manifest"
    if [ "${#v[@]}" -ne 3 ]; then
        echo ok
        return 0
    fi
    pv="${p[0]}.${p[1]}.${p[2]}"
    vv="${v[0]}.${v[1]}.${v[2]}"
    for i in 0 1 2; do
        if [ "${p[$i]}" -lt "${v[$i]}" ]; then
            printf 'older %s %s\n' "$pv" "$vv"
            return 0
        fi
        if [ "${p[$i]}" -gt "${v[$i]}" ]; then
            break
        fi
    done
    echo ok
}

preflight() {
    local fg timeout profile detail value pv vv _
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
    profile="$(profile_state)"
    if [ "$fg" = "ok" ] && [ "$timeout" = "ok" ]; then
        detail="foreground dispatch and a ${value} ms Bash timeout are set"
    else
        detail="start Claude Code with CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 and BASH_DEFAULT_TIMEOUT_MS=${TIMEOUT_FLOOR} exported"
    fi
    printf 'foreground: %s\n' "$fg"
    printf 'timeout:    %s\n' "$timeout"
    printf 'profile:    %s\n' "$profile"
    printf 'detail:     %s\n' "$detail"
    if [ "$fg" = "ok" ] && [ "$timeout" = "ok" ] && [[ "$profile" == older\ * ]]; then
        read -r _ pv vv <<< "$profile"
        printf '\nYour next message is the three lines below and nothing else: every character as written, asterisks included, no sentence of your own around them. Send it before your next tool call, then carry on.\n\n'
        printf "**This project's tce config is older than the plugin.**\n\n"
        printf '**Profile: %s. Plugin: %s.**\n\n' "$pv" "$vv"
        printf '**Run `/tce:init` to bring it up to date. This run continues.**\n'
    fi
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
