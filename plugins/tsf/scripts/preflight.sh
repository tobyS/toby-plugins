#!/bin/bash

# The environment contract check (DESIGN.md §12) plus the runner checks.
# Invoked by /tsf:init (contract check; identity check at the credential step)
# and by /tsf:cycle at the start of every cycle (all checks).
#
# Usage: preflight.sh --prepare P --env-up P --env-reset P --verify P [--env-check P]
#                     [--foreground] [--bash-timeout]
#                     [--identity --credential env|proxy --factory-login L --responders a,b]
#
#   Contract paths are relative to the project root (or absolute). Every
#   mandatory command must exist and be executable; env_check only when it is
#   registered.
#   --foreground  check that CLAUDE_CODE_DISABLE_BACKGROUND_TASKS is exactly
#                 "1" in this environment: without it, agents dispatched from
#                 an interactive session run in the background and a cycle
#                 cannot wait for them.
#   --bash-timeout
#                 check that BASH_DEFAULT_TIMEOUT_MS is at least 600000 (ten
#                 minutes). A project's verification suite routinely outlives
#                 the two-minute default, and a command that reaches its
#                 timeout is moved to the background -- which the foreground
#                 requirement above forbids -- or, with background tasks
#                 disabled, meets an outcome Claude Code does not document.
#                 Either way the cycle cannot trust the result. Only the
#                 default is checked: the effective ceiling is the larger of
#                 BASH_DEFAULT_TIMEOUT_MS and BASH_MAX_TIMEOUT_MS, so raising
#                 the default to 600000 raises both without depending on
#                 BASH_MAX_TIMEOUT_MS above its own documented default.
#   --identity    resolve the factory credential from the configured source
#                 (never the session's ambient gh login) and check with
#                 GET /user that it authenticates, against GitHub itself, as
#                 the factory login -- and that the factory login is not a
#                 responder (the human would be reviewing their own PRs).
#
# Prints exactly these lines:
#   now:        <UTC timestamp, YYYY-MM-DDTHH:MMZ>
#   prepare:    ok | missing | not-executable
#   env_up:     ok | missing | not-executable
#   env_reset:  ok | missing | not-executable
#   verify:     ok | missing | not-executable
#   env_check:  ok | missing | not-executable | not-registered
#   foreground: ok | missing | skipped
#   bash_timeout: ok | too-low | missing | skipped
#   identity:   ok | mismatch | responder | unavailable | skipped
#   login:      <the login GET /user returned, or ->
#   result:     ok | incomplete
#   detail:     <one line naming every failing item, or "all checks passed">
#
# result is ok only when every mandatory command is ok, env_check is ok or
# not-registered, and every requested runner check is ok. Every reported
# outcome exits 0; only usage errors exit 1.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Error: missing or invalid arguments" >&2
    echo "Usage: $0 --prepare P --env-up P --env-reset P --verify P [--env-check P]" >&2
    echo "          [--foreground] [--bash-timeout]" >&2
    echo "          [--identity --credential env|proxy --factory-login L --responders a,b]" >&2
    exit 1
}

PREPARE=""; ENV_UP=""; ENV_RESET=""; VERIFY=""; ENV_CHECK=""
FOREGROUND=0; BASH_TIMEOUT=0; IDENTITY=0; CREDENTIAL=""; FACTORY_LOGIN=""; RESPONDERS=""
# The floor the --bash-timeout check enforces, in milliseconds.
BASH_TIMEOUT_FLOOR=600000
while [ $# -gt 0 ]; do
    case "$1" in
        --prepare)       PREPARE="${2:-}"; shift 2 || usage ;;
        --env-up)        ENV_UP="${2:-}"; shift 2 || usage ;;
        --env-reset)     ENV_RESET="${2:-}"; shift 2 || usage ;;
        --verify)        VERIFY="${2:-}"; shift 2 || usage ;;
        --env-check)     ENV_CHECK="${2:-}"; shift 2 || usage ;;
        --foreground)    FOREGROUND=1; shift ;;
        --bash-timeout)  BASH_TIMEOUT=1; shift ;;
        --identity)      IDENTITY=1; shift ;;
        --credential)    CREDENTIAL="${2:-}"; shift 2 || usage ;;
        --factory-login) FACTORY_LOGIN="${2:-}"; shift 2 || usage ;;
        --responders)    RESPONDERS="${2:-}"; shift 2 || usage ;;
        *) usage ;;
    esac
done
{ [ -n "$PREPARE" ] && [ -n "$ENV_UP" ] && [ -n "$ENV_RESET" ] && [ -n "$VERIFY" ]; } || usage
if [ "$IDENTITY" = "1" ]; then
    case "$CREDENTIAL" in env|proxy) ;; *) usage ;; esac
    [ -n "$FACTORY_LOGIN" ] || usage
fi

cd "$(tsf_project_root)"

FAILURES=""
fail() { FAILURES="${FAILURES:+$FAILURES; }$1"; }

check_script() {
    CHECK_PATH="$1"
    if [ ! -e "$CHECK_PATH" ]; then
        CHECK_RESULT=missing
    elif [ ! -x "$CHECK_PATH" ]; then
        CHECK_RESULT=not-executable
    else
        CHECK_RESULT=ok
    fi
}

check_script "$PREPARE";   R_PREPARE="$CHECK_RESULT"
check_script "$ENV_UP";    R_ENV_UP="$CHECK_RESULT"
check_script "$ENV_RESET"; R_ENV_RESET="$CHECK_RESULT"
check_script "$VERIFY";    R_VERIFY="$CHECK_RESULT"
[ "$R_PREPARE" = "ok" ]   || fail "prepare $R_PREPARE ($PREPARE)"
[ "$R_ENV_UP" = "ok" ]    || fail "env_up $R_ENV_UP ($ENV_UP)"
[ "$R_ENV_RESET" = "ok" ] || fail "env_reset $R_ENV_RESET ($ENV_RESET)"
[ "$R_VERIFY" = "ok" ]    || fail "verify $R_VERIFY ($VERIFY)"
if [ -n "$ENV_CHECK" ]; then
    check_script "$ENV_CHECK"; R_ENV_CHECK="$CHECK_RESULT"
    [ "$R_ENV_CHECK" = "ok" ] || fail "env_check $R_ENV_CHECK ($ENV_CHECK)"
else
    R_ENV_CHECK=not-registered
fi

R_FOREGROUND=skipped
if [ "$FOREGROUND" = "1" ]; then
    if [ "${CLAUDE_CODE_DISABLE_BACKGROUND_TASKS:-}" = "1" ]; then
        R_FOREGROUND=ok
    else
        R_FOREGROUND=missing
        fail "foreground missing (start the runner with CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 exported)"
    fi
fi

R_BASH_TIMEOUT=skipped
if [ "$BASH_TIMEOUT" = "1" ]; then
    BT="${BASH_DEFAULT_TIMEOUT_MS:-}"
    case "$BT" in
        ''|*[!0-9]*)
            R_BASH_TIMEOUT=missing
            fail "bash_timeout missing (export BASH_DEFAULT_TIMEOUT_MS=$BASH_TIMEOUT_FLOOR before starting the runner)" ;;
        *)
            if [ "$BT" -ge "$BASH_TIMEOUT_FLOOR" ]; then
                R_BASH_TIMEOUT=ok
            else
                R_BASH_TIMEOUT=too-low
                fail "bash_timeout too-low (BASH_DEFAULT_TIMEOUT_MS is $BT, at least $BASH_TIMEOUT_FLOOR is required)"
            fi ;;
    esac
fi

R_IDENTITY=skipped
LOGIN="-"
if [ "$IDENTITY" = "1" ]; then
    if tsf_in_list "$FACTORY_LOGIN" "$RESPONDERS"; then
        R_IDENTITY=responder
        fail "identity responder (the factory login $FACTORY_LOGIN is also a responder)"
    elif ! tsf_identity factory "$CREDENTIAL"; then
        R_IDENTITY=unavailable
        fail "identity unavailable (credential source env, but GH_TOKEN is not set)"
    else
        tsf_api_retry GET user
        if [ "$TSF_API_CLASS" != "ok" ]; then
            R_IDENTITY=unavailable
            fail "identity unavailable ($TSF_API_DETAIL)"
        elif [ "$TSF_API_GITHUB" != "yes" ]; then
            R_IDENTITY=unavailable
            fail "identity unavailable (GET user answered without GitHub headers, so it did not come from GitHub)"
        else
            LOGIN="$(jq -r '.login // "-"' "$TSF_API_BODY")"
            if tsf_in_list "$LOGIN" "$FACTORY_LOGIN"; then
                R_IDENTITY=ok
            else
                R_IDENTITY=mismatch
                fail "identity mismatch (the credential authenticates as $LOGIN, not the factory login $FACTORY_LOGIN)"
            fi
        fi
    fi
fi

printf 'now:        %s\n' "$(date -u +%Y-%m-%dT%H:%MZ)"
printf 'prepare:    %s\n' "$R_PREPARE"
printf 'env_up:     %s\n' "$R_ENV_UP"
printf 'env_reset:  %s\n' "$R_ENV_RESET"
printf 'verify:     %s\n' "$R_VERIFY"
printf 'env_check:  %s\n' "$R_ENV_CHECK"
printf 'foreground: %s\n' "$R_FOREGROUND"
printf 'bash_timeout: %s\n' "$R_BASH_TIMEOUT"
printf 'identity:   %s\n' "$R_IDENTITY"
printf 'login:      %s\n' "$LOGIN"
if [ -z "$FAILURES" ]; then
    printf 'result:     %s\n' "ok"
    printf 'detail:     %s\n' "all checks passed"
else
    printf 'result:     %s\n' "incomplete"
    printf 'detail:     %s\n' "$FAILURES"
fi
exit 0
