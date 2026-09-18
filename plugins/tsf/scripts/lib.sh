#!/bin/bash

# Shared helpers for the tsf scripts. Sourced, never executed.
#
# These scripts ship inside the tsf plugin, so they cannot assume their own
# location relates to the project. The project root is wherever Claude Code is
# running -- for /tsf:cycle that is the factory clone (DESIGN.md §5.3).
#
# No tsf script reads .claude/tsf/config.md: the calling command resolves every
# value from it and passes it as an argument (the branch.sh division of labour).
#
# Every GitHub call goes through tsf_api (REST via `gh api`, never porcelain),
# which classifies the outcome -- the single most important piece of logic in
# the tsf scripts:
#
#   ok         2xx.
#   rejected   non-2xx WITH GitHub response headers (X-GitHub-Request-Id).
#              GitHub answered and said no. Note GitHub returns 404, not 403,
#              for missing permissions on private resources. Never retried.
#   denied     non-2xx WITHOUT GitHub response headers: a credential proxy or
#              sandbox refused the request before it reached GitHub. Never
#              retried.
#   transport  no HTTP status line at all (DNS, connection refused, timeout).
#              The only class tsf_api_retry retries, once.
#   auth       `gh` exit code 4: gh has no credential to send. Never retried.

# Resolve the project root: prefer CLAUDE_PROJECT_DIR, fall back to the current
# working directory (Claude runs Bash from there).
tsf_project_root() {
    printf '%s\n' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

# One private temp directory per script run, removed on exit.
tsf_tmp() {
    if [ -z "${TSF_TMP:-}" ]; then
        TSF_TMP="$(mktemp -d "${TMPDIR:-/tmp}/tsf.XXXXXX")"
        trap 'rm -rf "$TSF_TMP"' EXIT
    fi
}

# tsf_identity <as> <credential>
#   Prepare this script's own environment so `gh api` (and git push) act as
#   the requested identity, resolved explicitly per call (DESIGN.md §12):
#     factory env    -- GH_TOKEN must be set (it takes precedence over gh's
#                       keyring login); returns 1 when it is empty.
#     factory proxy  -- leave the environment alone: a proxy injects the
#                       credential by repository URL, and any GH_TOKEN present
#                       may be a phantom, so it is never asserted on.
#     ambient        -- unset GH_TOKEN and GITHUB_TOKEN so gh uses the
#                       keyring login: the human's login, deliberately.
#   Returns 2 on an invalid combination.
tsf_identity() {
    case "${1:-}:${2:-}" in
        factory:env)
            [ -n "${GH_TOKEN:-}" ] || return 1
            export GH_TOKEN
            ;;
        factory:proxy) ;;
        ambient:*) unset GH_TOKEN GITHUB_TOKEN ;;
        *) return 2 ;;
    esac
    return 0
}

# tsf_api <method> <path> [gh api args...]
#   Runs one REST call with fixed Accept and API-version headers and never
#   exits. Sets:
#     TSF_API_STATUS  HTTP status, or empty when none was received
#     TSF_API_GITHUB  yes | no -- whether GitHub response headers were present
#     TSF_API_CLASS   ok | rejected | denied | transport | auth (see above)
#     TSF_API_BODY    file holding the response body (overwritten per call;
#                     copy it before the next call if you still need it)
#     TSF_API_DETAIL  one line describing the outcome
#   Request bodies are passed with `--input <file>`.
tsf_api() {
    tsf_tmp
    TSF_API_METHOD="$1"
    TSF_API_PATH="$2"
    shift 2
    TSF_API_RAW="$TSF_TMP/api.raw"
    TSF_API_BODY="$TSF_TMP/api.body"
    TSF_API_ERR="$TSF_TMP/api.err"
    if gh api -X "$TSF_API_METHOD" --include \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$@" "$TSF_API_PATH" >"$TSF_API_RAW" 2>"$TSF_API_ERR"; then
        TSF_API_RC=0
    else
        TSF_API_RC=$?
    fi
    TSF_API_STATUS="$(sed -n '1s/^HTTP\/[0-9.]* \([0-9][0-9][0-9]\).*/\1/p' "$TSF_API_RAW")"
    # Headers end at the first empty line (CRLF-terminated); the body follows.
    awk 'b { print; next } /^\r?$/ { b = 1 }' "$TSF_API_RAW" >"$TSF_API_BODY"
    if awk '/^\r?$/ { exit } { print }' "$TSF_API_RAW" | grep -qi '^x-github-request-id:'; then
        TSF_API_GITHUB=yes
    else
        TSF_API_GITHUB=no
    fi

    if [ "$TSF_API_RC" = "4" ]; then
        TSF_API_CLASS=auth
    elif [ -z "$TSF_API_STATUS" ]; then
        TSF_API_CLASS=transport
    elif [ "$TSF_API_STATUS" -ge 200 ] && [ "$TSF_API_STATUS" -lt 300 ]; then
        TSF_API_CLASS=ok
    elif [ "$TSF_API_GITHUB" = "yes" ]; then
        TSF_API_CLASS=rejected
    else
        TSF_API_CLASS=denied
    fi

    TSF_API_MESSAGE="$(jq -r '.message? // .error? // empty' "$TSF_API_BODY" 2>/dev/null | head -1 || true)"
    case "$TSF_API_CLASS" in
        ok)        TSF_API_DETAIL="$TSF_API_METHOD $TSF_API_PATH: HTTP $TSF_API_STATUS" ;;
        rejected)  TSF_API_DETAIL="$TSF_API_METHOD $TSF_API_PATH: GitHub answered HTTP $TSF_API_STATUS ${TSF_API_MESSAGE:-}" ;;
        denied)    TSF_API_DETAIL="$TSF_API_METHOD $TSF_API_PATH: HTTP $TSF_API_STATUS without GitHub headers -- refused before reaching GitHub (proxy or sandbox) ${TSF_API_MESSAGE:-}" ;;
        transport) TSF_API_DETAIL="$TSF_API_METHOD $TSF_API_PATH: no HTTP response ($(tail -1 "$TSF_API_ERR" 2>/dev/null || true))" ;;
        auth)      TSF_API_DETAIL="$TSF_API_METHOD $TSF_API_PATH: gh has no credential to send ($(tail -1 "$TSF_API_ERR" 2>/dev/null || true))" ;;
    esac
}

# tsf_api_retry <method> <path> [gh api args...]
#   tsf_api, retried once when (and only when) the first attempt was a
#   transport error (DESIGN.md §10).
tsf_api_retry() {
    tsf_api "$@"
    if [ "$TSF_API_CLASS" = "transport" ]; then
        tsf_api "$@"
    fi
}

# tsf_api_list <path> <outfile> [array-key]
#   GET a list endpoint page by page (per_page=100, at most 10 pages) and
#   write the concatenated JSON array
#   to <outfile>. `gh api --paginate` is not used: combined with --include it
#   interleaves one header block per page. Leaves TSF_API_* describing the
#   last call, so a caller checks TSF_API_CLASS = ok afterwards.
#   Most list endpoints answer with a bare array. Some — the check-runs
#   endpoint among them — wrap it in an object: pass that object's array key as
#   <array-key> and every page is unwrapped before it is concatenated.
tsf_api_list() {
    tsf_tmp
    TSF_LIST_OUT="$2"
    TSF_LIST_KEY="${3:-}"
    printf '[]' >"$TSF_LIST_OUT"
    case "$1" in *\?*) TSF_LIST_SEP='&' ;; *) TSF_LIST_SEP='?' ;; esac
    TSF_LIST_PAGE=1
    while [ "$TSF_LIST_PAGE" -le 10 ]; do
        tsf_api_retry GET "$1${TSF_LIST_SEP}per_page=100&page=$TSF_LIST_PAGE"
        [ "$TSF_API_CLASS" = "ok" ] || return 0
        if [ -n "$TSF_LIST_KEY" ]; then
            jq --arg k "$TSF_LIST_KEY" '.[$k] // []' "$TSF_API_BODY" >"$TSF_TMP/list.page"
        else
            cp "$TSF_API_BODY" "$TSF_TMP/list.page"
        fi
        jq -s '.[0] + .[1]' "$TSF_LIST_OUT" "$TSF_TMP/list.page" >"$TSF_TMP/list.merge"
        mv "$TSF_TMP/list.merge" "$TSF_LIST_OUT"
        [ "$(jq 'length' "$TSF_TMP/list.page")" -ge 100 ] || return 0
        TSF_LIST_PAGE=$((TSF_LIST_PAGE + 1))
    done
}

# tsf_trailer <result> <status> <detail>
#   Print the common trailer and exit 0 (every reported outcome exits 0).
tsf_trailer() {
    printf 'result:    %s\n' "$1"
    printf 'status:    %s\n' "${2:--}"
    printf 'detail:    %s\n' "$3"
    exit 0
}

# tsf_api_fail
#   Report the last tsf_api outcome as a failure trailer and exit 0:
#   transport -> failed, rejected -> rejected, denied -> denied,
#   auth -> no-credential.
tsf_api_fail() {
    case "$TSF_API_CLASS" in
        transport) tsf_trailer "failed" "" "$TSF_API_DETAIL (after one retry)" ;;
        rejected)  tsf_trailer "rejected" "$TSF_API_STATUS" "$TSF_API_DETAIL" ;;
        denied)    tsf_trailer "denied" "$TSF_API_STATUS" "$TSF_API_DETAIL" ;;
        auth)      tsf_trailer "no-credential" "" "$TSF_API_DETAIL" ;;
        *)         tsf_trailer "failed" "$TSF_API_STATUS" "$TSF_API_DETAIL" ;;
    esac
}

# tsf_normalize_id <ref>
#   "#123", "123", "gh-123", "GH-123", an issue URL -> "GH-123".
#   Prints nothing and returns 1 for anything else.
tsf_normalize_id() {
    TSF_ID_REF="${1:-}"
    TSF_ID_REF="${TSF_ID_REF%%#issuecomment*}"
    TSF_ID_REF="${TSF_ID_REF%%\?*}"
    TSF_ID_REF="${TSF_ID_REF%/}"
    case "$TSF_ID_REF" in
        http://*/issues/*|https://*/issues/*) TSF_ID_REF="${TSF_ID_REF##*/issues/}" ;;
        '#'*) TSF_ID_REF="${TSF_ID_REF#\#}" ;;
        [Gg][Hh]-*) TSF_ID_REF="${TSF_ID_REF#??-}" ;;
    esac
    case "$TSF_ID_REF" in
        ''|*[!0-9]*) return 1 ;;
    esac
    printf 'GH-%s\n' "$((10#$TSF_ID_REF))"
}

# tsf_branch_for <pattern> <n>
#   Substitute the issue number for <n> in the branch pattern: gh-<n> -> gh-123.
tsf_branch_for() {
    printf '%s\n' "${1//<n>/$2}"
}

# tsf_in_list <needle> <comma-separated list>
#   Case-insensitive membership test (GitHub logins are case-insensitive).
tsf_in_list() {
    TSF_NEEDLE="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
    TSF_LIST="$(printf '%s' "${2:-}" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
    case ",$TSF_LIST," in
        *",$TSF_NEEDLE,"*) [ -n "$TSF_NEEDLE" ] ;;
        *) return 1 ;;
    esac
}
