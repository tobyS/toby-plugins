#!/bin/bash

# The backlog scan (DESIGN.md §5.1 step 1): open issues carrying a tsf:* state
# label, over REST. Invoked by /tsf:cycle.
#
# Usage: scan.sh --repo O/R --as factory --credential env|proxy
#                [--poll --responders a,b --factory-login L]
#                [--pr-probe --branch-pattern P --factory-login L]
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
#   --pr-probe  the pull-request side of the state machine (§5.1 step 1), for
#           tickets whose state is tsf:verify, tsf:dossier, tsf:needs-review,
#           tsf:rework or tsf:landing: the open pull request for the ticket
#           branch, the CI state of its head, and — for tsf:needs-review and
#           tsf:rework — the review state and the timestamp of the factory's
#           last comment on the pull request. The branch name comes from
#           --branch-pattern with <n> replaced by the issue number.
#
# Prints one record per issue, blank-line separated, oldest first:
#   issue:     <number>
#   state:     <the one tsf:* state label> | multiple (<a>,<b>)
#   priority:  yes | no
#   created:   <created_at>
#   updated:   <updated_at>
#   reply:     <comment id> | none | skipped   (skipped: no --poll, or not parked)
#   pr:        <number> | none | skipped       (skipped: no --pr-probe, or not in a PR state)
#   pr_head:   <head sha> | -
#   ci:        success | failure | pending | skipped
#   review:    approved | changes-requested | none | skipped
#   review_ref: <commit_id of the approval, or submitted_at of the request> | -
#   factory_comment: <created_at of the factory's last PR comment> | none | skipped
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
    echo "          [--pr-probe --branch-pattern P --factory-login L]" >&2
    exit 1
}

REPO=""; AS=""; CREDENTIAL=""; POLL=0; RESPONDERS=""; FACTORY_LOGIN=""
PR_PROBE=0; BRANCH_PATTERN=""
while [ $# -gt 0 ]; do
    case "$1" in
        --repo)           REPO="${2:-}"; shift 2 || usage ;;
        --as)             AS="${2:-}"; shift 2 || usage ;;
        --credential)     CREDENTIAL="${2:-}"; shift 2 || usage ;;
        --poll)           POLL=1; shift ;;
        --responders)     RESPONDERS="${2:-}"; shift 2 || usage ;;
        --factory-login)  FACTORY_LOGIN="${2:-}"; shift 2 || usage ;;
        --pr-probe)       PR_PROBE=1; shift ;;
        --branch-pattern) BRANCH_PATTERN="${2:-}"; shift 2 || usage ;;
        *) usage ;;
    esac
done
case "$REPO" in */*) ;; *) usage ;; esac
case "$AS:$CREDENTIAL" in factory:env|factory:proxy|ambient:*) ;; *) usage ;; esac
if [ "$POLL" = "1" ]; then
    { [ -n "$RESPONDERS" ] && [ -n "$FACTORY_LOGIN" ]; } || usage
fi
if [ "$PR_PROBE" = "1" ]; then
    { [ -n "$BRANCH_PATTERN" ] && [ -n "$FACTORY_LOGIN" ]; } || usage
    case "$BRANCH_PATTERN" in *"<n>"*) ;; *) usage ;; esac
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

# Probe the pull-request side for tickets whose state needs it.
PRDATA="$TSF_TMP/prdata.json"
printf '{}' >"$PRDATA"
if [ "$PR_PROBE" = "1" ]; then
    OWNER="${REPO%%/*}"
    for N in $(jq -r '.[] | select(.states | any(IN("tsf:verify","tsf:dossier","tsf:needs-review","tsf:rework","tsf:landing"))) | .number' "$ISSUES"); do
        STATE="$(jq -r --arg n "$N" '.[] | select(.number == ($n | tonumber)) | .states[0]' "$ISSUES")"
        BRANCH="$(tsf_branch_for "$BRANCH_PATTERN" "$N")"
        HEAD_FILTER="$(jq -rn --arg h "$OWNER:$BRANCH" '$h | @uri')"
        tsf_api_list "repos/$REPO/pulls?state=open&head=$HEAD_FILTER" "$TSF_TMP/pulls.json"
        if [ "$TSF_API_CLASS" != "ok" ]; then
            printf 'count:     %s\n' "0"
            tsf_api_fail
        fi
        PR_NUMBER="$(jq -r 'if length == 1 then .[0].number else "none" end' "$TSF_TMP/pulls.json")"
        PR_HEAD="$(jq -r 'if length == 1 then .[0].head.sha else "-" end' "$TSF_TMP/pulls.json")"
        CI="skipped"; REVIEW="none"; REVIEW_REF="-"; FACTORY_COMMENT="none"
        if [ "$PR_NUMBER" != "none" ]; then
            tsf_api_list "repos/$REPO/commits/$PR_HEAD/check-runs?filter=latest" "$TSF_TMP/runs.json" check_runs
            if [ "$TSF_API_CLASS" != "ok" ]; then
                printf 'count:     %s\n' "0"
                tsf_api_fail
            fi
            CI="$(jq -r '
                . as $runs
                | if ($runs | length) == 0 then "pending"
                  elif ([$runs[] | select(.status != "completed")] | length) > 0 then "pending"
                  elif ([$runs[] | select(.conclusion | IN("failure","timed_out","action_required","cancelled"))] | length) > 0 then "failure"
                  else "success" end' "$TSF_TMP/runs.json")"
            case "$STATE" in
                tsf:needs-review|tsf:rework)
                    tsf_api_list "repos/$REPO/pulls/$PR_NUMBER/reviews" "$TSF_TMP/reviews.json"
                    if [ "$TSF_API_CLASS" != "ok" ]; then
                        printf 'count:     %s\n' "0"
                        tsf_api_fail
                    fi
                    REVIEW="$(jq -r '
                        [.[] | select(.submitted_at != null and .user != null)
                             | select(.state | IN("APPROVED","CHANGES_REQUESTED","DISMISSED"))]
                        | group_by(.user.login | ascii_downcase)
                        | [.[] | sort_by(.submitted_at) | last]
                        | sort_by(.submitted_at) | last
                        | if . == null then "none"
                          elif .state == "APPROVED" then "approved"
                          elif .state == "CHANGES_REQUESTED" then "changes-requested"
                          else "none" end' "$TSF_TMP/reviews.json")"
                    REVIEW_REF="$(jq -r '
                        [.[] | select(.submitted_at != null and .user != null)
                             | select(.state | IN("APPROVED","CHANGES_REQUESTED","DISMISSED"))]
                        | group_by(.user.login | ascii_downcase)
                        | [.[] | sort_by(.submitted_at) | last]
                        | sort_by(.submitted_at) | last
                        | if . == null then "-"
                          elif .state == "APPROVED" then (.commit_id // "-")
                          else .submitted_at end' "$TSF_TMP/reviews.json")"
                    tsf_api_list "repos/$REPO/issues/$PR_NUMBER/comments" "$TSF_TMP/prcomments.json"
                    if [ "$TSF_API_CLASS" != "ok" ]; then
                        printf 'count:     %s\n' "0"
                        tsf_api_fail
                    fi
                    FACTORY_COMMENT="$(jq -r --arg factory "$FACTORY_LOGIN" '
                        [.[] | select((.user.login // "") | ascii_downcase == ($factory | ascii_downcase))]
                        | sort_by(.created_at, .id) | last
                        | if . == null then "none" else .created_at end' "$TSF_TMP/prcomments.json")"
                    ;;
                *) REVIEW="skipped"; FACTORY_COMMENT="skipped" ;;
            esac
        fi
        jq --arg n "$N" --arg pr "$PR_NUMBER" --arg head "$PR_HEAD" --arg ci "$CI" \
           --arg review "$REVIEW" --arg ref "$REVIEW_REF" --arg fc "$FACTORY_COMMENT" \
           '. + {($n): {pr: $pr, head: $head, ci: $ci, review: $review, review_ref: $ref, factory_comment: $fc}}' \
           "$PRDATA" >"$TSF_TMP/p.json"
        mv "$TSF_TMP/p.json" "$PRDATA"
    done
fi

jq -r --slurpfile replies "$REPLIES" --slurpfile prdata "$PRDATA" '
    sort_by(.created_at, .number)[]
    | "issue:     \(.number)",
      "state:     \(if (.states | length) == 1 then .states[0] else "multiple (\(.states | join(",")))" end)",
      "priority:  \(if .priority then "yes" else "no" end)",
      "created:   \(.created_at)",
      "updated:   \(.updated_at)",
      "reply:     \($replies[0][.number | tostring] // "skipped")",
      ($prdata[0][.number | tostring] // {}) as $p
      | "pr:        \($p.pr // "skipped")",
        "pr_head:   \($p.head // "-")",
        "ci:        \($p.ci // "skipped")",
        "review:    \($p.review // "skipped")",
        "review_ref: \($p.review_ref // "-")",
        "factory_comment: \($p.factory_comment // "skipped")",
        "title:     \(.title | gsub("[\\r\\n]+"; " "))",
        ""' "$ISSUES"
printf 'count:     %s\n' "$(jq 'length' "$ISSUES")"
tsf_trailer "ok" "" "scanned open issues of $REPO"
