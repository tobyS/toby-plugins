#!/bin/bash

# The backlog scan (DESIGN.md §5.1 step 1): open issues carrying a tsf:* state
# label, over REST. Invoked by /tsf:cycle.
#
# Usage: scan.sh --repo O/R --as factory --credential env|proxy
#                [--poll --responders a,b --factory-login L]
#
#   Reads GET /repos/O/R/issues?state=open (paged manually, 100 per page, at
#   most 10 pages) and filters client-side -- /search/issues is not used: it is
#   an index without a freshness guarantee and is refused by repository-scoped
#   credential proxies. Closed issues are never read (§9.4). Pull requests,
#   which the issues listing includes, are dropped. tsf:priority is a modifier,
#   not a state: an issue whose only tsf:* label is tsf:priority is invisible.
#
#   --poll  the comment-pickup fallback (§3.4) for projects without the pickup
#           workflow: for every tsf:needs-answer / tsf:needs-plan-approval
#           issue, read its comments (one call per parked ticket) and report the
#           first comment by a responder after the factory login's last
#           comment. Comments by anyone else are ignored.
#
# Prints one record per issue, blank-line separated, oldest first:
#   issue:     <number>
#   state:     <the one tsf:* state label> | multiple (<a>,<b>)
#   priority:  yes | no
#   created:   <created_at>
#   updated:   <updated_at>
#   reply:     <comment id> | none | skipped   (skipped: no --poll, or not parked)
#   title:     <title on one line>
# then the trailer:
#   count:     <number of records>
#   result:    ok | failed | rejected | denied | no-credential
#   status:    <HTTP status of the failing call, or ->
#   detail:    <one line>
#
# On any non-ok result no records are printed. Every reported outcome exits 0;
# only usage errors exit 1.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Error: missing or invalid arguments" >&2
    echo "Usage: $0 --repo O/R --as factory --credential env|proxy [--poll --responders a,b --factory-login L]" >&2
    exit 1
}

REPO=""; AS=""; CREDENTIAL=""; POLL=0; RESPONDERS=""; FACTORY_LOGIN=""
while [ $# -gt 0 ]; do
    case "$1" in
        --repo)          REPO="${2:-}"; shift 2 || usage ;;
        --as)            AS="${2:-}"; shift 2 || usage ;;
        --credential)    CREDENTIAL="${2:-}"; shift 2 || usage ;;
        --poll)          POLL=1; shift ;;
        --responders)    RESPONDERS="${2:-}"; shift 2 || usage ;;
        --factory-login) FACTORY_LOGIN="${2:-}"; shift 2 || usage ;;
        *) usage ;;
    esac
done
case "$REPO" in */*) ;; *) usage ;; esac
case "$AS:$CREDENTIAL" in factory:env|factory:proxy|ambient:*) ;; *) usage ;; esac
if [ "$POLL" = "1" ]; then
    { [ -n "$RESPONDERS" ] && [ -n "$FACTORY_LOGIN" ]; } || usage
fi

if ! tsf_identity "$AS" "$CREDENTIAL"; then
    printf 'count:     %s\n' "0"
    tsf_trailer "no-credential" "" "credential source env, but GH_TOKEN is not set"
fi
tsf_tmp

# Collect every open issue carrying a tsf:* state label.
tsf_api_list "repos/$REPO/issues?state=open" "$TSF_TMP/open.json"
if [ "$TSF_API_CLASS" != "ok" ]; then
    printf 'count:     %s\n' "0"
    tsf_api_fail
fi
ISSUES="$TSF_TMP/issues.json"
jq '[.[]
    | select(.pull_request == null)
    | { number, title, created_at, updated_at,
        states: [.labels[].name | select(startswith("tsf:") and . != "tsf:priority")],
        priority: ([.labels[].name] | index("tsf:priority") != null) }
    | select(.states | length > 0)]' "$TSF_TMP/open.json" >"$ISSUES"

# Poll parked tickets for a responder reply after the factory's last comment.
REPLIES="$TSF_TMP/replies.json"
printf '{}' >"$REPLIES"
if [ "$POLL" = "1" ]; then
    RESPONDERS_JSON="$(printf '%s' "$RESPONDERS" | tr '[:upper:]' '[:lower:]' | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; ""))')"
    for N in $(jq -r '.[] | select(.states == ["tsf:needs-answer"] or .states == ["tsf:needs-plan-approval"]) | .number' "$ISSUES"); do
        tsf_api_list "repos/$REPO/issues/$N/comments" "$TSF_TMP/comments.json"
        if [ "$TSF_API_CLASS" != "ok" ]; then
            printf 'count:     %s\n' "0"
            tsf_api_fail
        fi
        REPLY="$(jq -r --arg factory "$FACTORY_LOGIN" --argjson responders "$RESPONDERS_JSON" '
            ([.[] | select((.user.login | ascii_downcase) == ($factory | ascii_downcase)) | .id] | max // 0) as $last
            | [.[] | select(.id > $last and ((.user.login | ascii_downcase) as $l | $responders | index($l) != null)) | .id]
            | min // "none"' "$TSF_TMP/comments.json")"
        jq --arg n "$N" --arg reply "$REPLY" '. + {($n): $reply}' "$REPLIES" >"$TSF_TMP/r.json"
        mv "$TSF_TMP/r.json" "$REPLIES"
    done
fi

jq -r --slurpfile replies "$REPLIES" '
    sort_by(.created_at, .number)[]
    | "issue:     \(.number)",
      "state:     \(if (.states | length) == 1 then .states[0] else "multiple (\(.states | join(",")))" end)",
      "priority:  \(if .priority then "yes" else "no" end)",
      "created:   \(.created_at)",
      "updated:   \(.updated_at)",
      "reply:     \($replies[0][.number | tostring] // "skipped")",
      "title:     \(.title | gsub("[\\r\\n]+"; " "))",
      ""' "$ISSUES"
printf 'count:     %s\n' "$(jq 'length' "$ISSUES")"
tsf_trailer "ok" "" "scanned open issues of $REPO"
