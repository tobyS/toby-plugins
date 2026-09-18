#!/bin/bash

# GitHub reads over REST. Invoked by /tsf:cycle (issue, reply, branch, pr,
# checks, reviews, pr-comments), /tsf:spec (branch) and /tsf:init (whoami).
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
#   pr      --branch B
#     The open pull request whose head is the ticket branch. The design assumes
#     exactly one; two or more is a state a human must sort out.
#     exists:  yes | no
#     number:  <n> | -
#     url:     <html_url> | -
#     head:    <head sha> | -
#     base:    <base branch> | -
#     title:   <title on one line> | -
#     <trailer, result: ok | mismatch | ...>
#
#   checks  --ref SHA
#     CI state for a commit, from the check-runs endpoint. GitHub Actions
#     results are check runs and never appear in the combined-status endpoint,
#     which is why that endpoint is not used here.
#     state:   success | failure | pending
#     counts:  total=<n> success=<n> failure=<n> pending=<n>
#     failed:  <check names, comma-separated> | -
#     <trailer>
#     Mapping: any run whose status is not "completed" -> pending; otherwise any
#     conclusion in failure, timed_out, action_required or cancelled -> failure;
#     success, neutral and skipped count as success. Zero check runs is reported
#     as pending: a working factory presupposes CI on pull requests, and GitHub
#     documents no way to tell "no CI configured" from "not started yet" (see
#     TODO.md).
#
#   reviews --pr N
#     The review state per reviewer, reduced to the two facts the state machine
#     needs (DESIGN.md §4 row 10).
#     approval:  <commit_id of the latest approving review> | none
#     changes:   <submitted_at of the latest changes-requested review> | none
#     reviewers: <n>
#     <trailer>
#     detail-list:
#     --- <login> <state> <commit_id> <submitted_at> ---
#     ... one line per reviewer's latest decisive review
#     Reviews come back in chronological order with no sort parameter, so the
#     reduction happens here: reviews without submitted_at (PENDING) and with a
#     null user are dropped, COMMENTED is not decisive and is ignored, and the
#     latest decisive review per login wins.
#
#   pr-comments --pr N --factory-login L
#     last-factory: <created_at of the factory's last comment> | none
#     id:           <that comment's id> | -
#     <trailer>
#     A pull request's conversation comments are issue comments. The endpoint
#     documents no ordering, so the comments are sorted here by created_at then
#     id.
#
# The trailer is:
#   result:    ok | mismatch | failed | rejected | denied | no-credential
#   status:    <HTTP status of the failing call, or ->
#   detail:    <one line>
# Verbatim text (body:, text:, detail-list:) always comes after the trailer, so
# it can contain anything. On a non-ok result only the trailer is printed.
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
    echo "       $0 pr     --repo O/R --as ... --branch B" >&2
    echo "       $0 checks --repo O/R --as ... --ref SHA" >&2
    echo "       $0 reviews --repo O/R --as ... --pr N" >&2
    echo "       $0 pr-comments --repo O/R --as ... --pr N --factory-login L" >&2
    exit 1
}

MODE="${1:-}"
[ -n "$MODE" ] || usage
shift
REPO=""; AS=""; CREDENTIAL=""; ISSUE=""; RESPONDERS=""; FACTORY_LOGIN=""; BRANCH=""
PR=""; REF=""
while [ $# -gt 0 ]; do
    case "$1" in
        --repo)          REPO="${2:-}"; shift 2 || usage ;;
        --as)            AS="${2:-}"; shift 2 || usage ;;
        --credential)    CREDENTIAL="${2:-}"; shift 2 || usage ;;
        --issue)         ISSUE="${2:-}"; shift 2 || usage ;;
        --responders)    RESPONDERS="${2:-}"; shift 2 || usage ;;
        --factory-login) FACTORY_LOGIN="${2:-}"; shift 2 || usage ;;
        --branch)        BRANCH="${2:-}"; shift 2 || usage ;;
        --pr)            PR="${2:-}"; shift 2 || usage ;;
        --ref)           REF="${2:-}"; shift 2 || usage ;;
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
    pr)     [ -n "$BRANCH" ] || usage ;;
    checks) [ -n "$REF" ] || usage ;;
    reviews) case "$PR" in ''|*[!0-9]*) usage ;; esac ;;
    pr-comments) case "$PR" in ''|*[!0-9]*) usage ;; esac
            [ -n "$FACTORY_LOGIN" ] || usage ;;
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

pr)
    OWNER="${REPO%%/*}"
    HEAD_FILTER="$(jq -rn --arg h "$OWNER:$BRANCH" '$h | @uri')"
    tsf_api_list "repos/$REPO/pulls?state=open&head=$HEAD_FILTER" "$TSF_TMP/pulls.json"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    COUNT="$(jq 'length' "$TSF_TMP/pulls.json")"
    if [ "$COUNT" = "0" ]; then
        printf 'exists:    %s\n' "no"
        printf 'number:    %s\n' "-"
        printf 'url:       %s\n' "-"
        printf 'head:      %s\n' "-"
        printf 'base:      %s\n' "-"
        printf 'title:     %s\n' "-"
        tsf_trailer "ok" "$TSF_API_STATUS" "no open pull request with head $BRANCH"
    fi
    if [ "$COUNT" != "1" ]; then
        tsf_trailer "mismatch" "$TSF_API_STATUS" "$COUNT open pull requests with head $BRANCH ($(jq -r '[.[].number] | join(",")' "$TSF_TMP/pulls.json")); the factory expects exactly one"
    fi
    jq -r '.[0] | "exists:    yes",
           "number:    \(.number)",
           "url:       \(.html_url)",
           "head:      \(.head.sha)",
           "base:      \(.base.ref)",
           "title:     \(.title | gsub("[\\r\\n]+"; " "))"' "$TSF_TMP/pulls.json"
    tsf_trailer "ok" "$TSF_API_STATUS" "pull request #$(jq -r '.[0].number' "$TSF_TMP/pulls.json") for $BRANCH"
    ;;

checks)
    tsf_api_list "repos/$REPO/commits/$REF/check-runs?filter=latest" "$TSF_TMP/checkruns.json" check_runs
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    jq -r '
        [.[] | {name, status, conclusion}] as $runs
        | ([$runs[] | select(.status != "completed")] | length) as $pending
        | ([$runs[] | select(.status == "completed" and (.conclusion | IN("failure","timed_out","action_required","cancelled")))]) as $failed
        | ([$runs[] | select(.status == "completed" and (.conclusion | IN("success","neutral","skipped")))] | length) as $ok
        | (if ($runs | length) == 0 then "pending"
           elif $pending > 0 then "pending"
           elif ($failed | length) > 0 then "failure"
           else "success" end) as $state
        | "state:     \($state)",
          "counts:    total=\($runs | length) success=\($ok) failure=\($failed | length) pending=\($pending)",
          "failed:    \(if ($failed | length) == 0 then "-" else ([$failed[].name] | join(",")) end)"
        ' "$TSF_TMP/checkruns.json"
    tsf_trailer "ok" "$TSF_API_STATUS" "$(jq 'length' "$TSF_TMP/checkruns.json") check run(s) on $REF"
    ;;

reviews)
    tsf_api_list "repos/$REPO/pulls/$PR/reviews" "$TSF_TMP/reviews.json"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    jq '[.[]
         | select(.submitted_at != null and .user != null)
         | select(.state | IN("APPROVED","CHANGES_REQUESTED","DISMISSED"))
         | {login: .user.login, state, commit_id, submitted_at}]
        | group_by(.login | ascii_downcase)
        | [.[] | sort_by(.submitted_at) | last]
        | sort_by(.submitted_at)' "$TSF_TMP/reviews.json" >"$TSF_TMP/latest.json"
    jq -r '"approval:  \([.[] | select(.state == "APPROVED")] | last | if . == null then "none" else .commit_id end)",
           "changes:   \([.[] | select(.state == "CHANGES_REQUESTED")] | last | if . == null then "none" else .submitted_at end)",
           "reviewers: \(length)"' "$TSF_TMP/latest.json"
    printf 'result:    %s\n' "ok"
    printf 'status:    %s\n' "$TSF_API_STATUS"
    printf 'detail:    %s\n' "read the reviews of pull request #$PR"
    printf 'detail-list:\n'
    jq -r '.[] | "--- \(.login) \(.state) \(.commit_id // "-") \(.submitted_at) ---"' "$TSF_TMP/latest.json"
    exit 0
    ;;

pr-comments)
    tsf_api_list "repos/$REPO/issues/$PR/comments" "$TSF_TMP/prcomments.json"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    jq -r --arg factory "$FACTORY_LOGIN" '
        [.[] | select((.user.login // "") | ascii_downcase == ($factory | ascii_downcase))]
        | sort_by(.created_at, .id)
        | last
        | if . == null then "last-factory: none", "id:        -"
          else "last-factory: \(.created_at)", "id:        \(.id)" end' \
        "$TSF_TMP/prcomments.json"
    tsf_trailer "ok" "$TSF_API_STATUS" "read the comments of pull request #$PR"
    ;;
esac
