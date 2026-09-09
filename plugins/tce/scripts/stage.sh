#!/bin/bash

# Derive each ticket's tce workflow stage: its research document, its plan
# document, and how far the plan's implementation has got.
# Usage: stage.sh <ticket-id> [<ticket-id> ...]
#
# The ticket IDs are whatever canonical form the project's ticket system uses
# (see .claude/tce/tickets.md) -- this script never reads that file and knows
# nothing about ticket systems. Enumerating which tickets exist is the calling
# command's job; this script only maps IDs onto thoughts/ documents.
#
# Prints one record per ID, in the order given, separated by a blank line:
#   ticket:   <id>
#   research: <path relative to the project root, empty when none>
#   plan:     <path relative to the project root, empty when none>
#   progress: <n>/<m> | ?/<m> | <empty>
#   source:   log | sidecar | unknown | no-plan
#
# progress/source semantics:
#   log      -- exact: counted from the plan's own `### Implementation log`
#               blocks.
#   sidecar  -- approximate: the plan carries no log blocks but a legacy
#               `<plan>.status.md` sidecar exists. That format was never
#               standardized, so the caller must mark the number approximate.
#   unknown  -- a plan exists but carries no progress signal at all; progress
#               is reported as ?/<m>.
#   no-plan  -- no plan document; progress is empty.
#
# Phase counting deliberately ignores success-criteria checkboxes: completed
# plans routinely leave Manual Verification items unticked (they are ticked
# only on human confirmation), so a checkbox ratio is not a progress signal.
# Fenced code blocks are stripped before any heading is matched -- plans that
# quote markdown otherwise report phases and closeouts that are only examples.
#
# Every reported outcome exits 0; only usage errors and a missing thoughts/
# directory exit 1.
#
# The project root is resolved from the project (see lib.sh), not from this
# script's location -- it ships inside the tce plugin.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

if [ -z "$1" ]; then
    echo "Usage: $0 <ticket-id> [<ticket-id> ...]"
    echo "Example: $0 MYAPP-0042 MYAPP-0043"
    exit 1
fi

ROOT="$(tce_project_root)"
THOUGHTS_DIR="$ROOT/thoughts"

if [ ! -d "$THOUGHTS_DIR" ]; then
    echo "Error: thoughts directory not found at $THOUGHTS_DIR" >&2
    exit 1
fi

RESEARCH_DIR="$THOUGHTS_DIR/shared/research"
PLANS_DIR="$THOUGHTS_DIR/shared/plans"

# Find the document in $1 belonging to ticket ID $2, or print nothing.
#
# A file belongs to the ID when its basename contains "-<id>-" or ends with
# "-<id>.md". That is deliberately stricter than ticket.sh's substring match:
# a substring match would let MYAPP-0100 claim MYAPP-0100a's documents, which
# would give an epic its sub-tickets' research and plan.
#
# Globs expand in collation order and the documents are date-prefixed, so the
# last match is the newest -- if a ticket was researched or planned twice, the
# later document is the current one.
#
# $3 = "skip-status" to ignore legacy *.status.md sidecars (their basenames
# also contain "-<id>-", so a plan lookup must exclude them).
find_doc() {
    doc_dir="$1"
    doc_id="$2"
    doc_skip="$3"
    doc_match=""

    [ -d "$doc_dir" ] || return 0

    for candidate in "$doc_dir"/*.md; do
        [ -e "$candidate" ] || continue
        candidate_base="$(basename "$candidate")"
        if [ "$doc_skip" = "skip-status" ]; then
            case "$candidate_base" in
                *.status.md) continue ;;
            esac
        fi
        case "$candidate_base" in
            *-"$doc_id"-*|*-"$doc_id".md) doc_match="$candidate" ;;
        esac
    done

    [ -n "$doc_match" ] && printf '%s\n' "$doc_match"
    return 0
}

# Count phases and completed phases in a plan document.
# Prints "<done> <total> <has_log>".
plan_progress() {
    awk '
        # Strip fenced code blocks. A fence opens with three or more backticks
        # or tildes and closes with at least as many of the same character.
        # Plans in a plugin repo quote the plugins own markdown, so headings
        # inside fences are examples, not real phases.
        {
            if (match($0, /^[ \t]*(```+|~~~+)/)) {
                marker = substr($0, RSTART, RLENGTH)
                gsub(/[ \t]/, "", marker)
                fence_this = substr(marker, 1, 1)
                len_this = length(marker)
                if (!in_fence) {
                    in_fence = 1; fence_ch = fence_this; fence_len = len_this
                    next
                } else if (fence_this == fence_ch && len_this >= fence_len) {
                    in_fence = 0
                    next
                }
            }
            if (in_fence) next
        }

        # Phase headings vary across eras: "## Phase 1: Name", "### Phase 1 -
        # Name", and a trailing decoration such as " DONE". Interval
        # expressions are avoided because the awk shipped on some systems does
        # not support them. A trailing letter ("Phase 1b") marks a sub-phase
        # that is not counted.
        /^##[ \t]+Phase[ \t]+[0-9]/ || /^###[ \t]+Phase[ \t]+[0-9]/ {
            rest = $0
            sub(/^#+[ \t]+Phase[ \t]+[0-9]+/, "", rest)
            if (rest !~ /^[a-zA-Z]/) {
                phases++
                in_log = 0
                next
            }
        }

        /^###[ \t]+Implementation log/ { in_log = 1; has_log = 1; next }

        in_log && /^[ \t]*-[ \t]*\*\*Status\*\*:/ {
            if (index($0, "\342\234\205") > 0 || index($0, "Complete") > 0) done++
            in_log = 0
            next
        }

        /^#/ { in_log = 0 }

        END { printf "%d %d %d\n", done, phases, has_log }
    ' "$1"
}

# Count completed phases in a legacy .status.md sidecar. Prints "<done>".
#
# The sidecar format was never standardized -- it predates the in-plan log --
# so this recognizes every shape the format took, which is why the caller must
# present the number as approximate. Two layouts, five done-markers:
#
#   Section layout -- a "## Phase N" heading opens a section, and the phase
#   counts as done when the section carries any of: a checked box
#   ("- [x] Done -- ..."), a status line with or without ** markers whose value
#   says complete ("- **Status**: Complete", "- Status: complete"), a line
#   opening with the done glyph, or a heading that itself ends in DONE.
#
#   List layout -- no "## Phase N" headings at all, just "- [x] Phase 1: ..."
#   entries that are themselves the phase list. (A "## Phases" plural heading
#   is not a phase heading: a digit must follow "Phase".)
sidecar_progress() {
    awk '
        function flush() { if (cur && cur_done) sec_done++ }

        {
            if (match($0, /^[ \t]*(```+|~~~+)/)) {
                marker = substr($0, RSTART, RLENGTH)
                gsub(/[ \t]/, "", marker)
                fence_this = substr(marker, 1, 1)
                len_this = length(marker)
                if (!in_fence) {
                    in_fence = 1; fence_ch = fence_this; fence_len = len_this
                    next
                } else if (fence_this == fence_ch && len_this >= fence_len) {
                    in_fence = 0
                    next
                }
            }
            if (in_fence) next
        }

        /^#+[ \t]+Phase[ \t]+[0-9]/ {
            flush()
            cur = 1
            sec_total++
            cur_done = ($0 ~ /DONE[ \t]*$/) ? 1 : 0
            next
        }

        /^[ \t]*-[ \t]*\[[xX ]\][ \t]*Phase[ \t]+[0-9]/ {
            list_total++
            if ($0 ~ /^[ \t]*-[ \t]*\[[xX]\]/) {
                list_done++
                if (cur) cur_done = 1
            }
            next
        }

        cur && /^[ \t]*-[ \t]*\[[xX]\]/ { cur_done = 1; next }

        cur && /^[ \t]*-?[ \t]*(\*\*)?Status(\*\*)?[ \t]*:/ {
            value = $0
            sub(/^[^:]*:/, "", value)
            if (index(value, "\342\234\205") > 0 || tolower(value) ~ /(^|[^a-z])complete/) {
                cur_done = 1
            }
            next
        }

        cur {
            stripped = $0
            sub(/^[ \t]+/, "", stripped)
            if (index(stripped, "\342\234\205") == 1) cur_done = 1
        }

        END {
            flush()
            if (sec_total > 0) print sec_done + 0
            else print list_done + 0
        }
    ' "$1"
}

FIRST=1

for TICKET in "$@"; do
    if [ "$FIRST" -eq 0 ]; then
        printf '\n'
    fi
    FIRST=0

    RESEARCH="$(find_doc "$RESEARCH_DIR" "$TICKET" "")"
    PLAN="$(find_doc "$PLANS_DIR" "$TICKET" "skip-status")"

    PROGRESS=""
    SOURCE="no-plan"

    if [ -n "$PLAN" ]; then
        read -r DONE TOTAL HAS_LOG <<EOF_PROGRESS
$(plan_progress "$PLAN")
EOF_PROGRESS

        if [ "$HAS_LOG" -eq 1 ]; then
            PROGRESS="$DONE/$TOTAL"
            SOURCE="log"
        else
            SIDECAR="${PLAN%.md}.status.md"
            if [ -f "$SIDECAR" ]; then
                SIDE_DONE="$(sidecar_progress "$SIDECAR")"
                if [ "$SIDE_DONE" -gt "$TOTAL" ]; then
                    SIDE_DONE="$TOTAL"
                fi
                PROGRESS="$SIDE_DONE/$TOTAL"
                SOURCE="sidecar"
            else
                SOURCE="unknown"
                if [ "$TOTAL" -gt 0 ]; then
                    PROGRESS="?/$TOTAL"
                fi
            fi
        fi
    fi

    printf 'ticket:   %s\n' "$TICKET"
    printf 'research: %s\n' "${RESEARCH:+${RESEARCH#"$ROOT"/}}"
    printf 'plan:     %s\n' "${PLAN:+${PLAN#"$ROOT"/}}"
    printf 'progress: %s\n' "$PROGRESS"
    printf 'source:   %s\n' "$SOURCE"
done
