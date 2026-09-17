#!/bin/bash

# Single-issue GitHub reads over REST. Invoked by /tsf:cycle (issue, reply,
# branch), /tsf:spec (branch) and /tsf:init (whoami).
#
# Usage: gh-read.sh <subcommand> --repo O/R --as factory|ambient [--credential env|proxy] ...
#
#   issue   --issue N
#     number:  <n>
#     title:   <title on one line>
#     state:   open | closed
#     labels:  <comma-separated label names, or ->
#     pull:    yes | no          (yes: the number is a pull request, not an issue)
#     <trailer>
#     body:
#     <the raw issue body, verbatim, to the end of the output>
#
#   reply   --issue N --responders a,b --factory-login L
#     Every comment by a responder after the factory login's last comment on
#     the issue (all comments, if the factory never commented). Comments by
#     anyone else are ignored (DESIGN.md §3.4).
#     reply:   <id of the first such comment> | none
#     count:   <number of such comments>
#     <trailer>
#     text:
#     --- <login> <created_at> ---
#     <comment body, verbatim>
#     ... one block per comment, to the end of the output
#
#   branch  --branch B
#     exists:  yes | no
#     sha:     <head sha> | -
#     <trailer>
#
#   whoami
#     login:   <login the credential authenticates as> | -
#     github:  yes | no          (whether the answer carried GitHub headers)
#     <trailer>
#
# The trailer is:
#   result:    ok | failed | rejected | denied | no-credential
#   status:    <HTTP status of the failing call, or ->
#   detail:    <one line>
# Verbatim text (body:, text:) always comes after the trailer, so it can
# contain anything. On a non-ok result only the trailer is printed.
#
# Every reported outcome exits 0; only usage errors exit 1.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Error: missing or invalid arguments" >&2
    echo "Usage: $0 issue  --repo O/R --as factory|ambient [--credential env|proxy] --issue N" >&2
    echo "       $0 reply  --repo O/R --as ... --issue N --responders a,b --factory-login L" >&2
    echo "       $0 branch --repo O/R --as ... --branch B" >&2
    echo "       $0 whoami --repo O/R --as ..." >&2
    exit 1
}

MODE="${1:-}"
[ -n "$MODE" ] || usage
shift
REPO=""; AS=""; CREDENTIAL=""; ISSUE=""; RESPONDERS=""; FACTORY_LOGIN=""; BRANCH=""
while [ $# -gt 0 ]; do
    case "$1" in
        --repo)          REPO="${2:-}"; shift 2 || usage ;;
        --as)            AS="${2:-}"; shift 2 || usage ;;
        --credential)    CREDENTIAL="${2:-}"; shift 2 || usage ;;
        --issue)         ISSUE="${2:-}"; shift 2 || usage ;;
        --responders)    RESPONDERS="${2:-}"; shift 2 || usage ;;
        --factory-login) FACTORY_LOGIN="${2:-}"; shift 2 || usage ;;
        --branch)        BRANCH="${2:-}"; shift 2 || usage ;;
        *) usage ;;
    esac
done
case "$REPO" in */*) ;; *) usage ;; esac
case "$AS:$CREDENTIAL" in factory:env|factory:proxy|ambient:*) ;; *) usage ;; esac
case "$MODE" in
    issue)  case "$ISSUE" in ''|*[!0-9]*) usage ;; esac ;;
    reply)  case "$ISSUE" in ''|*[!0-9]*) usage ;; esac
            { [ -n "$RESPONDERS" ] && [ -n "$FACTORY_LOGIN" ]; } || usage ;;
    branch) [ -n "$BRANCH" ] || usage ;;
    whoami) ;;
    *) usage ;;
esac

if ! tsf_identity "$AS" "$CREDENTIAL"; then
    tsf_trailer "no-credential" "" "credential source env, but GH_TOKEN is not set"
fi
tsf_tmp

case "$MODE" in

issue)
    tsf_api_retry GET "repos/$REPO/issues/$ISSUE"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    jq -r '"number:    \(.number)",
           "title:     \(.title | gsub("[\\r\\n]+"; " "))",
           "state:     \(.state)",
           "labels:    \([.labels[].name] | if length == 0 then "-" else join(",") end)",
           "pull:      \(if .pull_request == null then "no" else "yes" end)"' "$TSF_API_BODY"
    cp "$TSF_API_BODY" "$TSF_TMP/issue.json"
    printf 'result:    %s\n' "ok"
    printf 'status:    %s\n' "$TSF_API_STATUS"
    printf 'detail:    %s\n' "read issue #$ISSUE"
    printf 'body:\n'
    jq -r '.body // ""' "$TSF_TMP/issue.json"
    exit 0
    ;;

reply)
    tsf_api_list "repos/$REPO/issues/$ISSUE/comments" "$TSF_TMP/comments.json"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    RESPONDERS_JSON="$(printf '%s' "$RESPONDERS" | tr '[:upper:]' '[:lower:]' | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; ""))')"
    jq --arg factory "$FACTORY_LOGIN" --argjson responders "$RESPONDERS_JSON" '
        ([.[] | select((.user.login | ascii_downcase) == ($factory | ascii_downcase)) | .id] | max // 0) as $last
        | [.[] | select(.id > $last and ((.user.login | ascii_downcase) as $l | $responders | index($l) != null))]
        | sort_by(.id)' "$TSF_TMP/comments.json" >"$TSF_TMP/replies.json"
    jq -r '"reply:     \(if length == 0 then "none" else (.[0].id | tostring) end)",
           "count:     \(length)"' "$TSF_TMP/replies.json"
    printf 'result:    %s\n' "ok"
    printf 'status:    %s\n' "$TSF_API_STATUS"
    printf 'detail:    %s\n' "read the comments of issue #$ISSUE"
    printf 'text:\n'
    jq -r '.[] | "--- \(.user.login) \(.created_at) ---", (.body // "")' "$TSF_TMP/replies.json"
    exit 0
    ;;

branch)
    tsf_api_retry GET "repos/$REPO/git/ref/heads/$BRANCH"
    if [ "$TSF_API_CLASS" = "ok" ]; then
        printf 'exists:    %s\n' "yes"
        printf 'sha:       %s\n' "$(jq -r '.object.sha' "$TSF_API_BODY")"
        tsf_trailer "ok" "$TSF_API_STATUS" "branch $BRANCH exists"
    fi
    if [ "$TSF_API_CLASS" = "rejected" ] && [ "$TSF_API_STATUS" = "404" ]; then
        printf 'exists:    %s\n' "no"
        printf 'sha:       %s\n' "-"
        tsf_trailer "ok" "$TSF_API_STATUS" "branch $BRANCH does not exist"
    fi
    tsf_api_fail
    ;;

whoami)
    tsf_api_retry GET "user"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    printf 'login:     %s\n' "$(jq -r '.login // "-"' "$TSF_API_BODY")"
    printf 'github:    %s\n' "$TSF_API_GITHUB"
    tsf_trailer "ok" "$TSF_API_STATUS" "authenticated"
    ;;
esac
