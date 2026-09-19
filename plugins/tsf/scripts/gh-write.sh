#!/bin/bash

# The one REST write helper (DESIGN.md §10, §11.3). Every GitHub write tsf
# performs goes through this script: /tsf:cycle as the factory identity,
# /tsf:spec and /tsf:init as the human (--as ambient).
#
# Usage: gh-write.sh <subcommand> --repo O/R --as factory|ambient [--credential env|proxy] ...
#
#   comment       --issue N --body-file F
#                 POST issues/N/comments; the 201 response is the read-back.
#                   id:        <comment id>
#                   url:       <html_url>
#                 result: ok
#
#   labels        --issue N (--set tsf:<state> | --clear)
#                 Re-read the issue's labels immediately before the write, then
#                 replace the whole set: every non-tsf:* label and tsf:priority
#                 pass through unchanged, every other tsf:* label is dropped and
#                 <state> added -- exactly one state label remains (§3.4).
#                 --clear does the same but adds no state label, leaving the
#                 issue with none: the merge cycle's last write, because a
#                 closed ticket is nobody's move (§3.4, §9.3 step 5).
#                 Read back and compared.
#                   previous:  <the tsf:* state label(s) before, comma-separated, or ->
#                   labels:    <the label set after the write>
#                 result: ok | mismatch
#
#   marker        --issue N --ticket GH-N --branch B [--journal] [--pr P]
#                 Replace the block between "<!-- tsf:links -->" and
#                 "<!-- /tsf:links -->" in the issue body, or append it after a
#                 blank line. The human-written body above the block is never
#                 modified (§3.2). Read back: the block must be present.
#                 result: ok | mismatch
#
#   issue-create  --title T --body-file F
#                   number:    <issue number>
#                   url:       <html_url>
#                 result: created
#
#   label-create  --name X --color HEX --description D
#                 POST labels; an existing label (422 already_exists) is updated
#                 in place instead.
#                 result: created | updated
#
#   ref-create    --branch B --from BASE
#                 Create branch B at the head of BASE. Read back.
#                   sha:       <head sha of B>
#                 result: created | exists | mismatch
#
#   pr-create     --branch B --base BASE --title T --body-file F
#                 POST …/pulls with draft:false — the draft default is not
#                 documented, so it is always passed. A 422 means a pull request
#                 for this head/base already exists: it is looked up and
#                 reported, so a re-run is idempotent.
#                   number:    <pull request number>
#                   url:       <html_url>
#                   head:      <head sha>
#                 result: created | exists
#
#   contents-put  --branch B --path P --file F --message M
#                 Commit file F at path P on branch B through the contents API
#                 (creating or updating it). Read back.
#                   commit:    <commit sha>
#                 result: created | updated | mismatch
#
# The landing's three writes (§9.3). Each has ROUTINE outcomes that are neither
# retried nor parked -- they are the state machine's own branches, not failures:
#
#   update-branch --pr N --expected-head SHA
#                 PUT …/pulls/N/update-branch: the server merges the base
#                 branch into the pull request branch. Merge only -- the REST
#                 endpoint has no rebase (and §16.5 forbids one anyway).
#                 --expected-head is mandatory and must be the full 40-character
#                 sha: the parameter defaults to the current head, so omitting
#                 it is no guard at all, and a short sha is refused.
#                 The call is asynchronous: a 202 means accepted, and the head
#                 moves shortly after.
#                   previous_head: <the head the call was made against>
#                 result: synced      202
#                         up-to-date  422, the base branch has no new commits
#                         conflict    422, the merge conflicts -- the branch is
#                                     untouched and the merge-resolver takes over
#                         head-moved  422, expected_head_sha did not match
#                 A 422 whose message matches none of the three is reported as
#                 failed with the body in detail:, never guessed at.
#
#   merge         --pr N --sha SHA --title T --message-file F
#                 PUT …/pulls/N/merge with merge_method=squash. --sha is
#                 mandatory: without the head guard a concurrent push would be
#                 merged unreviewed.
#                   merge_sha: <the squash commit>
#                   merged:    true
#                 result: merged      200
#                         blocked     405, the merge cannot be performed; the
#                                     reason: line carries GitHub's own message
#                                     (missing approval, failing or pending
#                                     required check, not up to date, conflict)
#                         head-moved  409, the sha guard fired
#
#   ref-delete    --branch B
#                 DELETE …/git/refs/heads/B, after the merge where the
#                 repository does not delete the branch itself (§9.4). The
#                 repository setting is deliberately never read: the bare
#                 repository object is not reachable under every proxy
#                 allowlist. Read the ref first and delete only what is there.
#                 result: deleted  204
#                         absent   404, or a 422 saying the reference does not
#                                  exist -- a success: something got there first
#
# Every subcommand ends with the trailer:
#   result:    <per subcommand above> | rejected | denied | failed | no-credential
#   status:    <HTTP status of the deciding call, or ->
#   detail:    <one line>
# Subcommand fields are printed only on success. Every call is retried once
# on a transport error; a second transport failure reports result: failed.
# Parking the ticket on a failure is the caller's decision, not this script's.
#
# The label write: DESIGN.md §3.4 and §10 call it "the full-set PATCH"; the
# replace-all endpoint is PUT /repos/O/R/issues/N/labels. GitHub offers no
# concurrency guard on any issue, label or comment write (no If-Match, no
# conflict status) -- every write is last-write-wins. The re-read immediately
# before the PUT narrows the window in which a human edit could be lost; it
# is a mitigation, not a guarantee.
#
# Every reported outcome exits 0; only usage errors exit 1.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Error: missing or invalid arguments" >&2
    echo "Usage: $0 comment      --repo O/R --as factory|ambient [--credential env|proxy] --issue N --body-file F" >&2
    echo "       $0 labels       --repo O/R --as ... --issue N (--set tsf:<state> | --clear)" >&2
    echo "       $0 marker       --repo O/R --as ... --issue N --ticket GH-N --branch B [--journal] [--pr P]" >&2
    echo "       $0 issue-create --repo O/R --as ... --title T --body-file F" >&2
    echo "       $0 label-create --repo O/R --as ... --name X --color HEX --description D" >&2
    echo "       $0 ref-create   --repo O/R --as ... --branch B --from BASE" >&2
    echo "       $0 pr-create    --repo O/R --as ... --branch B --base BASE --title T --body-file F" >&2
    echo "       $0 contents-put --repo O/R --as ... --branch B --path P --file F --message M" >&2
    echo "       $0 update-branch --repo O/R --as ... --pr N --expected-head SHA" >&2
    echo "       $0 merge        --repo O/R --as ... --pr N --sha SHA --title T --message-file F" >&2
    echo "       $0 ref-delete   --repo O/R --as ... --branch B" >&2
    exit 1
}

MODE="${1:-}"
[ -n "$MODE" ] || usage
shift
REPO=""; AS=""; CREDENTIAL=""; ISSUE=""; BODY_FILE=""; SET=""; TICKET=""; BRANCH=""
JOURNAL=0; PR=""; TITLE=""; NAME=""; COLOR=""; DESCRIPTION=""; FROM=""; FILE_PATH=""
FILE=""; MESSAGE=""; CLEAR=0; EXPECTED_HEAD=""; SHA=""; MESSAGE_FILE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --repo)        REPO="${2:-}"; shift 2 || usage ;;
        --as)          AS="${2:-}"; shift 2 || usage ;;
        --credential)  CREDENTIAL="${2:-}"; shift 2 || usage ;;
        --issue)       ISSUE="${2:-}"; shift 2 || usage ;;
        --body-file)   BODY_FILE="${2:-}"; shift 2 || usage ;;
        --set)         SET="${2:-}"; shift 2 || usage ;;
        --clear)       CLEAR=1; shift ;;
        --expected-head) EXPECTED_HEAD="${2:-}"; shift 2 || usage ;;
        --sha)         SHA="${2:-}"; shift 2 || usage ;;
        --message-file) MESSAGE_FILE="${2:-}"; shift 2 || usage ;;
        --ticket)      TICKET="${2:-}"; shift 2 || usage ;;
        --branch)      BRANCH="${2:-}"; shift 2 || usage ;;
        --journal)     JOURNAL=1; shift ;;
        --pr)          PR="${2:-}"; shift 2 || usage ;;
        --title)       TITLE="${2:-}"; shift 2 || usage ;;
        --name)        NAME="${2:-}"; shift 2 || usage ;;
        --color)       COLOR="${2:-}"; shift 2 || usage ;;
        --description) DESCRIPTION="${2:-}"; shift 2 || usage ;;
        --from|--base) FROM="${2:-}"; shift 2 || usage ;;
        --path)        FILE_PATH="${2:-}"; shift 2 || usage ;;
        --file)        FILE="${2:-}"; shift 2 || usage ;;
        --message)     MESSAGE="${2:-}"; shift 2 || usage ;;
        *) usage ;;
    esac
done
case "$REPO" in */*) ;; *) usage ;; esac
case "$AS:$CREDENTIAL" in factory:env|factory:proxy|ambient:*) ;; *) usage ;; esac
is_number() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; esac; }
case "$MODE" in
    comment)      is_number "$ISSUE" && [ -f "$BODY_FILE" ] || usage ;;
    labels)       is_number "$ISSUE" || usage
                  # Exactly one of --set / --clear.
                  if [ "$CLEAR" = "1" ]; then
                      [ -z "$SET" ] || usage
                  else
                      case "$SET" in tsf:priority|tsf:) usage ;; tsf:*) ;; *) usage ;; esac
                  fi ;;
    marker)       is_number "$ISSUE" && [ -n "$TICKET" ] && [ -n "$BRANCH" ] || usage
                  [ -z "$PR" ] || is_number "$PR" || usage ;;
    issue-create) [ -n "$TITLE" ] && [ -f "$BODY_FILE" ] || usage ;;
    label-create) [ -n "$NAME" ] && [ -n "$COLOR" ] || usage ;;
    ref-create)   [ -n "$BRANCH" ] && [ -n "$FROM" ] || usage ;;
    pr-create)    [ -n "$BRANCH" ] && [ -n "$FROM" ] && [ -n "$TITLE" ] && [ -f "$BODY_FILE" ] || usage ;;
    contents-put) [ -n "$BRANCH" ] && [ -n "$FILE_PATH" ] && [ -f "$FILE" ] && [ -n "$MESSAGE" ] || usage ;;
    update-branch) is_number "$PR" || usage
                  # A short sha is refused by GitHub with the same 422 the other
                  # cases use, so it is rejected here where the message is clear.
                  case "$EXPECTED_HEAD" in
                      [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
                      *) usage ;;
                  esac ;;
    merge)        is_number "$PR" && [ -n "$SHA" ] && [ -n "$TITLE" ] && [ -f "$MESSAGE_FILE" ] || usage ;;
    ref-delete)   [ -n "$BRANCH" ] || usage ;;
    *) usage ;;
esac

if ! tsf_identity "$AS" "$CREDENTIAL"; then
    tsf_trailer "no-credential" "" "credential source env, but GH_TOKEN is not set"
fi
tsf_tmp
REQUEST="$TSF_TMP/request.json"

case "$MODE" in

comment)
    jq -Rs '{body: .}' <"$BODY_FILE" >"$REQUEST"
    tsf_api_retry POST "repos/$REPO/issues/$ISSUE/comments" --input "$REQUEST"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    ID="$(jq -r '.id // empty' "$TSF_API_BODY")"
    [ -n "$ID" ] || tsf_trailer "mismatch" "$TSF_API_STATUS" "the comment response carries no id"
    printf 'id:        %s\n' "$ID"
    printf 'url:       %s\n' "$(jq -r '.html_url' "$TSF_API_BODY")"
    tsf_trailer "ok" "$TSF_API_STATUS" "posted comment $ID on #$ISSUE"
    ;;

labels)
    tsf_api_retry GET "repos/$REPO/issues/$ISSUE"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    PREVIOUS="$(jq -r '[.labels[].name | select(startswith("tsf:") and . != "tsf:priority")] | if length == 0 then "-" else join(",") end' "$TSF_API_BODY")"
    # --clear adds no state label: the closed issue is left with none (§3.4).
    jq --arg set "$SET" --argjson clear "$CLEAR" '{labels: (
            [.labels[].name | select(startswith("tsf:") | not)]
            + [.labels[].name | select(. == "tsf:priority")]
            + (if $clear == 1 then [] else [$set] end))}' "$TSF_API_BODY" >"$REQUEST"
    tsf_api_retry PUT "repos/$REPO/issues/$ISSUE/labels" --input "$REQUEST"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    tsf_api_retry GET "repos/$REPO/issues/$ISSUE"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    AFTER="$(jq -r '[.labels[].name] | sort | join(",")' "$TSF_API_BODY")"
    WANTED="$(jq -r '.labels | sort | join(",")' "$REQUEST")"
    if [ "$AFTER" != "$WANTED" ]; then
        tsf_trailer "mismatch" "$TSF_API_STATUS" "read-back label set is [$AFTER], expected [$WANTED]"
    fi
    printf 'previous:  %s\n' "$PREVIOUS"
    printf 'labels:    %s\n' "$AFTER"
    if [ "$CLEAR" = "1" ]; then
        tsf_trailer "ok" "$TSF_API_STATUS" "#$ISSUE left with no tsf:* state label"
    fi
    tsf_trailer "ok" "$TSF_API_STATUS" "#$ISSUE labelled $SET"
    ;;

marker)
    BASE_URL="https://github.com/$REPO"
    LINKS="[spec]($BASE_URL/blob/$BRANCH/thoughts/factory/$TICKET/spec.md) · [branch]($BASE_URL/tree/$BRANCH)"
    [ "$JOURNAL" = "0" ] || LINKS="$LINKS · [journal]($BASE_URL/blob/$BRANCH/thoughts/factory/$TICKET/journal.md)"
    [ -z "$PR" ] || LINKS="$LINKS · [PR]($BASE_URL/pull/$PR)"
    BLOCK="$(printf '<!-- tsf:links -->\n**tsf:** %s\n<!-- /tsf:links -->' "$LINKS")"

    tsf_api_retry GET "repos/$REPO/issues/$ISSUE"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    # Split on the markers rather than slicing by index, so multi-byte text in
    # the human's body cannot shift an offset.
    jq --arg block "$BLOCK" '
        (.body // "") as $b
        | ($b | split("<!-- tsf:links -->")) as $head
        | if ($head | length) >= 2 and (($head[1:] | join("<!-- tsf:links -->")) | contains("<!-- /tsf:links -->")) then
            ($head[1:] | join("<!-- tsf:links -->") | split("<!-- /tsf:links -->")) as $tail
            | {body: ($head[0] + $block + ($tail[1:] | join("<!-- /tsf:links -->")))}
          elif $b == "" then
            {body: $block}
          else
            {body: ($b + "\n\n" + $block)}
          end' "$TSF_API_BODY" >"$REQUEST"
    tsf_api_retry PATCH "repos/$REPO/issues/$ISSUE" --input "$REQUEST"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    tsf_api_retry GET "repos/$REPO/issues/$ISSUE"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    if ! jq -e --arg block "$BLOCK" '(.body // "") | gsub("\r\n"; "\n") | contains($block)' "$TSF_API_BODY" >/dev/null; then
        tsf_trailer "mismatch" "$TSF_API_STATUS" "the marker block is not present in the read-back body of #$ISSUE"
    fi
    tsf_trailer "ok" "$TSF_API_STATUS" "marker block on #$ISSUE up to date"
    ;;

issue-create)
    jq -Rs --arg title "$TITLE" '{title: $title, body: .}' <"$BODY_FILE" >"$REQUEST"
    tsf_api_retry POST "repos/$REPO/issues" --input "$REQUEST"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    NUMBER="$(jq -r '.number // empty' "$TSF_API_BODY")"
    [ -n "$NUMBER" ] || tsf_trailer "mismatch" "$TSF_API_STATUS" "the issue response carries no number"
    printf 'number:    %s\n' "$NUMBER"
    printf 'url:       %s\n' "$(jq -r '.html_url' "$TSF_API_BODY")"
    tsf_trailer "created" "$TSF_API_STATUS" "created issue #$NUMBER"
    ;;

label-create)
    COLOR="${COLOR#\#}"
    jq -n --arg name "$NAME" --arg color "$COLOR" --arg description "$DESCRIPTION" \
        '{name: $name, color: $color, description: $description}' >"$REQUEST"
    tsf_api_retry POST "repos/$REPO/labels" --input "$REQUEST"
    if [ "$TSF_API_CLASS" = "ok" ]; then
        tsf_trailer "created" "$TSF_API_STATUS" "created label $NAME"
    fi
    if [ "$TSF_API_CLASS" = "rejected" ] && [ "$TSF_API_STATUS" = "422" ] \
            && jq -e 'any(.errors[]?; .code == "already_exists")' "$TSF_API_BODY" >/dev/null 2>&1; then
        ENCODED="$(jq -rn --arg name "$NAME" '$name | @uri')"
        jq -n --arg color "$COLOR" --arg description "$DESCRIPTION" \
            '{color: $color, description: $description}' >"$REQUEST"
        tsf_api_retry PATCH "repos/$REPO/labels/$ENCODED" --input "$REQUEST"
        [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
        tsf_trailer "updated" "$TSF_API_STATUS" "label $NAME already existed; colour and description updated"
    fi
    tsf_api_fail
    ;;

ref-create)
    tsf_api_retry GET "repos/$REPO/git/ref/heads/$FROM"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    SHA="$(jq -r '.object.sha' "$TSF_API_BODY")"
    jq -n --arg ref "refs/heads/$BRANCH" --arg sha "$SHA" '{ref: $ref, sha: $sha}' >"$REQUEST"
    tsf_api_retry POST "repos/$REPO/git/refs" --input "$REQUEST"
    RESULT=created
    if [ "$TSF_API_CLASS" != "ok" ]; then
        if [ "$TSF_API_CLASS" = "rejected" ] && [ "$TSF_API_STATUS" = "422" ] \
                && jq -e '(.message // "") | test("already exists"; "i")' "$TSF_API_BODY" >/dev/null 2>&1; then
            RESULT=exists
        else
            tsf_api_fail
        fi
    fi
    tsf_api_retry GET "repos/$REPO/git/ref/heads/$BRANCH"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    HEAD_SHA="$(jq -r '.object.sha' "$TSF_API_BODY")"
    if [ "$RESULT" = "created" ] && [ "$HEAD_SHA" != "$SHA" ]; then
        tsf_trailer "mismatch" "$TSF_API_STATUS" "branch $BRANCH reads back at $HEAD_SHA, expected $SHA"
    fi
    printf 'sha:       %s\n' "$HEAD_SHA"
    if [ "$RESULT" = "exists" ]; then
        tsf_trailer "exists" "$TSF_API_STATUS" "branch $BRANCH already exists at $HEAD_SHA"
    fi
    tsf_trailer "created" "$TSF_API_STATUS" "created $BRANCH from $FROM at $SHA"
    ;;

pr-create)
    jq -Rs --arg title "$TITLE" --arg head "$BRANCH" --arg base "$FROM" \
        '{title: $title, head: $head, base: $base, body: ., draft: false}' <"$BODY_FILE" >"$REQUEST"
    tsf_api_retry POST "repos/$REPO/pulls" --input "$REQUEST"
    if [ "$TSF_API_CLASS" = "ok" ]; then
        printf 'number:    %s\n' "$(jq -r '.number' "$TSF_API_BODY")"
        printf 'url:       %s\n' "$(jq -r '.html_url' "$TSF_API_BODY")"
        printf 'head:      %s\n' "$(jq -r '.head.sha' "$TSF_API_BODY")"
        tsf_trailer "created" "$TSF_API_STATUS" "opened pull request #$(jq -r '.number' "$TSF_API_BODY") from $BRANCH into $FROM"
    fi
    if [ "$TSF_API_CLASS" = "rejected" ] && [ "$TSF_API_STATUS" = "422" ]; then
        # A pull request for this head/base already exists — look it up so a
        # re-run of the same cycle is idempotent. Keep the refusal's message:
        # the lookup below overwrites TSF_API_MESSAGE.
        REFUSAL="$TSF_API_MESSAGE"
        OWNER="${REPO%%/*}"
        HEAD_FILTER="$(jq -rn --arg h "$OWNER:$BRANCH" '$h | @uri')"
        tsf_api_retry GET "repos/$REPO/pulls?state=open&head=$HEAD_FILTER&per_page=100"
        [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
        if [ "$(jq 'length' "$TSF_API_BODY")" = "1" ]; then
            printf 'number:    %s\n' "$(jq -r '.[0].number' "$TSF_API_BODY")"
            printf 'url:       %s\n' "$(jq -r '.[0].html_url' "$TSF_API_BODY")"
            printf 'head:      %s\n' "$(jq -r '.[0].head.sha' "$TSF_API_BODY")"
            tsf_trailer "exists" "422" "a pull request from $BRANCH is already open as #$(jq -r '.[0].number' "$TSF_API_BODY")"
        fi
        tsf_trailer "rejected" "422" "GitHub refused the pull request and no open one with head $BRANCH was found: $REFUSAL"
    fi
    tsf_api_fail
    ;;

contents-put)
    REF="$(jq -rn --arg ref "$BRANCH" '$ref | @uri')"
    tsf_api_retry GET "repos/$REPO/contents/$FILE_PATH?ref=$REF"
    OLD_SHA=""
    RESULT=created
    if [ "$TSF_API_CLASS" = "ok" ]; then
        OLD_SHA="$(jq -r '.sha' "$TSF_API_BODY")"
        RESULT=updated
    elif ! { [ "$TSF_API_CLASS" = "rejected" ] && [ "$TSF_API_STATUS" = "404" ]; }; then
        tsf_api_fail
    fi
    base64 <"$FILE" | tr -d '\n' >"$TSF_TMP/content.b64"
    jq -n --arg message "$MESSAGE" --arg branch "$BRANCH" --arg sha "$OLD_SHA" \
        --rawfile content "$TSF_TMP/content.b64" \
        '{message: $message, content: $content, branch: $branch} + (if $sha == "" then {} else {sha: $sha} end)' >"$REQUEST"
    tsf_api_retry PUT "repos/$REPO/contents/$FILE_PATH" --input "$REQUEST"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    COMMIT="$(jq -r '.commit.sha' "$TSF_API_BODY")"
    BLOB="$(jq -r '.content.sha' "$TSF_API_BODY")"
    tsf_api_retry GET "repos/$REPO/contents/$FILE_PATH?ref=$REF"
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    if [ "$(jq -r '.sha' "$TSF_API_BODY")" != "$BLOB" ]; then
        tsf_trailer "mismatch" "$TSF_API_STATUS" "$FILE_PATH on $BRANCH does not read back as the committed blob $BLOB"
    fi
    printf 'commit:    %s\n' "$COMMIT"
    tsf_trailer "$RESULT" "$TSF_API_STATUS" "committed $FILE_PATH on $BRANCH as $COMMIT"
    ;;

update-branch)
    jq -n --arg sha "$EXPECTED_HEAD" '{expected_head_sha: $sha}' >"$REQUEST"
    tsf_api_retry PUT "repos/$REPO/pulls/$PR/update-branch" --input "$REQUEST"
    if [ "$TSF_API_CLASS" = "ok" ]; then
        printf 'previous_head: %s\n' "$EXPECTED_HEAD"
        tsf_trailer "synced" "$TSF_API_STATUS" "the base branch was merged into the head branch of #$PR; the head moves shortly"
    fi
    # 422 covers three distinct, routine outcomes and an unknown remainder. The
    # message is the only discriminator GitHub offers -- none of this is
    # documented, so an unrecognized 422 is reported rather than assumed.
    if [ "$TSF_API_CLASS" = "rejected" ] && [ "$TSF_API_STATUS" = "422" ]; then
        case "$TSF_API_MESSAGE" in
            *"no new commits"*|*"not behind"*|*"up to date"*|*"up-to-date"*)
                tsf_trailer "up-to-date" "422" "the base branch has no new commits for #$PR" ;;
            *conflict*|*Conflict*|*"cannot be automatically merged"*)
                tsf_trailer "conflict" "422" "the base branch conflicts with #$PR; the branch is unchanged: $TSF_API_MESSAGE" ;;
            *"expected head sha"*|*"expected_head_sha"*|*"head ref"*)
                tsf_trailer "head-moved" "422" "the head of #$PR is no longer $EXPECTED_HEAD: $TSF_API_MESSAGE" ;;
            *)
                tsf_trailer "failed" "422" "unrecognized refusal of the update-branch call on #$PR: $TSF_API_MESSAGE" ;;
        esac
    fi
    tsf_api_fail
    ;;

merge)
    jq -Rs --arg title "$TITLE" --arg sha "$SHA" \
        '{merge_method: "squash", commit_title: $title, commit_message: ., sha: $sha}' \
        <"$MESSAGE_FILE" >"$REQUEST"
    tsf_api_retry PUT "repos/$REPO/pulls/$PR/merge" --input "$REQUEST"
    if [ "$TSF_API_CLASS" = "ok" ]; then
        MERGE_SHA="$(jq -r '.sha // empty' "$TSF_API_BODY")"
        [ -n "$MERGE_SHA" ] || tsf_trailer "mismatch" "$TSF_API_STATUS" "the merge response carries no sha"
        printf 'merge_sha: %s\n' "$MERGE_SHA"
        printf 'merged:    %s\n' "$(jq -r '.merged' "$TSF_API_BODY")"
        tsf_trailer "merged" "$TSF_API_STATUS" "squash-merged #$PR as $MERGE_SHA"
    fi
    if [ "$TSF_API_CLASS" = "rejected" ] && [ "$TSF_API_STATUS" = "405" ]; then
        printf 'reason:    %s\n' "$TSF_API_MESSAGE"
        tsf_trailer "blocked" "405" "GitHub will not merge #$PR: $TSF_API_MESSAGE"
    fi
    if [ "$TSF_API_CLASS" = "rejected" ] && [ "$TSF_API_STATUS" = "409" ]; then
        tsf_trailer "head-moved" "409" "the head of #$PR is no longer $SHA: $TSF_API_MESSAGE"
    fi
    tsf_api_fail
    ;;

ref-delete)
    tsf_api_retry GET "repos/$REPO/git/ref/heads/$BRANCH"
    if [ "$TSF_API_CLASS" = "rejected" ] && [ "$TSF_API_STATUS" = "404" ]; then
        tsf_trailer "absent" "404" "branch $BRANCH is already gone"
    fi
    [ "$TSF_API_CLASS" = "ok" ] || tsf_api_fail
    tsf_api_retry DELETE "repos/$REPO/git/refs/heads/$BRANCH"
    if [ "$TSF_API_CLASS" = "ok" ]; then
        tsf_trailer "deleted" "$TSF_API_STATUS" "deleted branch $BRANCH"
    fi
    # A ref that vanished between the read and the delete is reported 422 with
    # "Reference does not exist", not 404. Both mean the branch is gone.
    if [ "$TSF_API_CLASS" = "rejected" ] \
            && { [ "$TSF_API_STATUS" = "404" ] \
                 || { [ "$TSF_API_STATUS" = "422" ] && case "$TSF_API_MESSAGE" in *"does not exist"*) true ;; *) false ;; esac; }; }; then
        tsf_trailer "absent" "$TSF_API_STATUS" "branch $BRANCH is already gone"
    fi
    tsf_api_fail
    ;;
esac
