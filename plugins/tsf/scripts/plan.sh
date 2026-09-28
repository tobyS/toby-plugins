#!/bin/bash

# The plan parser (DESIGN.md §6.5, §7). Invoked by /tsf:cycle: `check` when the
# plan or implement step returns, `criteria` when a gate or the manual-verify
# step needs the plan's criteria.
#
# Usage: plan.sh check    --plan PATH
#        plan.sh criteria --plan PATH --out FILE --manual-out FILE
#
# Why a script and not the model: the dispatcher may not read a plan's body
# (cycle.md invariant 3), and model extraction of a hundred criteria into a
# spawn payload is both lossy and expensive. A script can only do it if the
# plan is reliably parsable -- and a model writes the plan, so conformance
# cannot be assumed, only enforced. That is what `check` is for: it runs when
# the plan agent returns and again when the implement agent returns (addenda
# are written then), and a failure is an invalid return, so a plan that does
# not parse never reaches the human's approval.
#
#   check     Validates the plan's structure:
#             - every `### Increment <n>: <name>` under `## Increments` carries
#               a `**Verification:**` or a `**Manual:**` field that states
#               something;
#             - increment numbers are unique;
#             - every `### <date> — Increment <n>: <name>` under `## Addenda`
#               names an increment that exists and carries the same fields.
#               increments: <n>
#               addenda:    <n>
#             result: ok | invalid
#
#   criteria  Writes the numbered criteria to --out and the manual items alone
#             to --manual-out, and reports how many of each. An increment that
#             yields no criterion is an error, not an empty line: a gate given
#             nothing to judge would pass silently.
#               criteria:   <n>
#               manual:     <n>
#             result: ok | invalid
#             The criteria themselves never reach stdout: the dispatcher passes
#             the paths on and must not hold plan content in its context.
#
# An **addendum restates**, it does not amend: the newest addendum for an
# increment replaces that increment's fields entirely. Implementation records
# deviations that way (§6.6) so the plan-compliance gate, which never sees the
# journal, judges what was actually built.
#
# LIBERAL IN SHAPE, STRICT IN SUBSTANCE (TP-0043). A field's marker is accepted
# with or without a leading bullet and with or without a qualifier inside the
# bold span, so `**Verification (restated in full):**` at column 0 reads the same
# as the canonical `- **Verification:**`. The plan template keeps showing exactly
# ONE form and never advertises the variants: a writing agent given one shape
# copies it, while one given a list has been invited to choose. Variants arrive
# regardless -- that is what this tolerance absorbs.
#
# A field's text runs to the NEXT field, bold bullet, heading or section -- never
# to the first blank line. It used to stop there, which silently dropped the body
# of every list-shaped or multi-paragraph restatement while `check` still
# reported ok: the plan-compliance gate then judged a criterion whose content had
# been thrown away. Confirmed on the GH-41 run's own approved plan, whose
# increment 1 lost the command that verifies it.
#
# A field that states nothing -- no character left once whitespace, emphasis and
# punctuation are removed -- makes the plan `invalid` in BOTH modes. The test
# lives in the parser, which stamps each FIELD record with a substance flag that
# the validation and the extraction both read, so `check` cannot pass a plan
# whose criteria would come out empty.
#
# FENCED CODE BLOCKS ARE STRIPPED BEFORE ANY HEADING IS MATCHED. A plan for a
# project that documents markdown quotes headings that look exactly like the
# real ones; tce's stage.sh learned this against this repository's own corpus
# (TP-0033), where in-fence headings were confirmed false positives.
#
# Every reported outcome exits 0; only usage errors exit 1.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Error: missing or invalid arguments" >&2
    echo "Usage: $0 check    --plan PATH" >&2
    echo "       $0 criteria --plan PATH --out FILE --manual-out FILE" >&2
    exit 1
}

MODE="${1:-}"
[ -n "$MODE" ] || usage
shift
PLAN=""; OUT=""; MANUAL_OUT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --plan)        PLAN="${2:-}"; shift 2 || usage ;;
        --out)         OUT="${2:-}"; shift 2 || usage ;;
        --manual-out)  MANUAL_OUT="${2:-}"; shift 2 || usage ;;
        *) usage ;;
    esac
done
case "$MODE" in
    check)    [ -n "$PLAN" ] || usage ;;
    criteria) { [ -n "$PLAN" ] && [ -n "$OUT" ] && [ -n "$MANUAL_OUT" ]; } || usage ;;
    *) usage ;;
esac

report() {
    printf 'result:     %s\n' "$1"
    printf 'detail:     %s\n' "$2"
    exit 0
}

if [ ! -f "$PLAN" ]; then
    case "$MODE" in
        check)    printf 'increments: %s\naddenda:    %s\n' "0" "0" ;;
        criteria) printf 'criteria:   %s\nmanual:     %s\n' "0" "0" ;;
    esac
    report "invalid" "no plan at $PLAN"
fi

tsf_tmp
STREAM="$TSF_TMP/stream"

# Parse into a normalized tab-separated stream:
#   INC   <n>  <name>
#   FIELD <n>  verification|manual  0|1  <text>
#   ADD   <n>  <date>               <name>
#   ERR   <message>
# Increment fields and addendum fields land in the same FIELD records: an
# addendum's fields are emitted after the increment's, and the last one for a
# (number, kind) pair wins -- which is exactly "an addendum restates".
#
# A FIELD record's fourth column is the substance flag and the text is LAST, so a
# tab surviving inside the text cannot shift the flag. Both readers below key on
# that one flag: there is no second notion of "empty".
awk '
# Does the text say anything, once the markup a reader ignores is removed? The
# parameter list declares t local -- the main program uses a global t.
function substantive(s, t) {
    t = s
    gsub(/[ \t]/, "", t)
    gsub(/[*_`]/, "", t)
    gsub(/[-:;,.!?()]/, "", t)
    gsub(/\[/, "", t)
    gsub(/\]/, "", t)
    return (t == "" ? "0" : "1")
}
function flush_field() {
    if (field_kind != "") {
        gsub(/^[ \t]+|[ \t]+$/, "", field_text)
        printf "FIELD\t%s\t%s\t%s\t%s\n", field_inc, field_kind, substantive(field_text), field_text
    }
    field_kind = ""; field_text = ""
}
{
    line = $0

    # Fenced blocks: a run of three or more backticks opens, and a run at least
    # as long closes. Everything between is invisible to every rule below.
    if (match(line, /^[ \t]*`+/)) {
        run = substr(line, RSTART, RLENGTH)
        gsub(/[ \t]/, "", run)
        ticks = length(run)
        if (ticks >= 3) {
            if (!in_fence) { in_fence = 1; fence_len = ticks; next }
            else if (ticks >= fence_len) { in_fence = 0; next }
        }
    }
    if (in_fence) next

    # Sections.
    if (line ~ /^## +Increments[ \t]*$/)  { flush_field(); section = "inc"; next }
    if (line ~ /^## +Addenda[ \t]*$/)     { flush_field(); section = "add"; next }
    if (line ~ /^## /)                    { flush_field(); section = "other"; next }

    # Increment headings.
    if (section == "inc" && line ~ /^### /) {
        flush_field()
        if (match(line, /^### +Increment +[0-9]+ *:/)) {
            n = line
            sub(/^### +Increment +/, "", n)
            sub(/ *:.*$/, "", n)
            name = line
            sub(/^### +Increment +[0-9]+ *: */, "", name)
            gsub(/[ \t]+$/, "", name)
            printf "INC\t%s\t%s\n", n, name
            current = n
        } else {
            printf "ERR\ta heading under ## Increments is not \"### Increment <n>: <name>\": %s\n", line
            current = ""
        }
        next
    }

    # Addendum headings: ### <date> — Increment <n>: <name>. The dash may be an
    # em dash or a hyphen; a plan is written by a model and both are natural.
    if (section == "add" && line ~ /^### /) {
        flush_field()
        if (match(line, /^### +[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] +(—|-|--) +Increment +[0-9]+ *:/)) {
            d = line
            sub(/^### +/, "", d)
            sub(/ .*$/, "", d)
            n = line
            sub(/^.*Increment +/, "", n)
            sub(/ *:.*$/, "", n)
            name = line
            sub(/^.*Increment +[0-9]+ *: */, "", name)
            gsub(/[ \t]+$/, "", name)
            printf "ADD\t%s\t%s\t%s\n", n, d, name
            current = n
        } else {
            printf "ERR\tan entry under ## Addenda is not \"### <YYYY-MM-DD> — Increment <n>: <name>\": %s\n", line
            current = ""
        }
        next
    }

    if (section != "inc" && section != "add") next

    # Fields of the current increment or addendum. The bullet is optional and so
    # is a qualifier inside the bold span -- `[^*]*` cannot cross an asterisk, so
    # it swallows ` (restated in full):` but never a following bold run.
    if (match(line, /^[ \t]*([-*+] +)?\*\*Verification[^*]*\*\*:?/)) {
        flush_field()
        if (current == "") next
        t = line; sub(/^[ \t]*([-*+] +)?\*\*Verification[^*]*\*\*:? */, "", t)
        field_inc = current; field_kind = "verification"; field_text = t
        next
    }
    if (match(line, /^[ \t]*([-*+] +)?\*\*Manual[^*]*\*\*:?/)) {
        flush_field()
        if (current == "") next
        t = line; sub(/^[ \t]*([-*+] +)?\*\*Manual[^*]*\*\*:? */, "", t)
        field_inc = current; field_kind = "manual"; field_text = t
        next
    }
    # Any other bold bullet ends the field: a **Depends on:** or **Where:** is
    # the next field of the increment, not part of this field.
    if (line ~ /^[ \t]*[-*+] +\*\*/) { flush_field(); next }
    # Everything else belongs to the field being collected -- blank lines and
    # column-0 prose included. A restatement is a list or several paragraphs as
    # often as it is one sentence, and the headings above have already flushed.
    if (field_kind != "") {
        t = line; gsub(/^[ \t]+|[ \t]+$/, "", t)
        if (t != "") field_text = (field_text == "" ? t : field_text " " t)
        next
    }
    flush_field()
}
END { flush_field() }
' "$PLAN" >"$STREAM"

INCREMENTS="$(grep -c '^INC	' "$STREAM" || true)"
ADDENDA="$(grep -c '^ADD	' "$STREAM" || true)"

# Errors that are the same for both modes: a malformed heading, a duplicate
# increment number, an increment with no field or none that states anything, an
# addendum naming an increment that does not exist or restating nothing.
#
# Only a SUBSTANTIVE field counts as a field here, which is what keeps `check`
# and `criteria` from ever disagreeing: the extraction below reads the same flag,
# so a plan can no longer pass the check while yielding an empty criterion.
PROBLEM="$(awk -F'\t' '
    $1 == "ERR" { print $2; exit }
    $1 == "INC" {
        if ($2 in seen) { print "increment " $2 " appears twice"; exit }
        seen[$2] = 1; order[++count] = $2; name[$2] = $3; next
    }
    $1 == "ADD" {
        if (!($2 in seen)) { print "the addendum dated " $3 " names increment " $2 ", which the plan does not have"; exit }
        addcount[$2]++; addfields[$2] = 0; lastadd[$2] = $3; next
    }
    $1 == "FIELD" {
        if ($4 == "1") {
            has[$2] = 1
            if ($2 in addcount && addcount[$2] > 0) addfields[$2] = 1
        } else {
            hollow[$2] = 1
        }
        next
    }
    END {
        for (i = 1; i <= count; i++) {
            n = order[i]
            if (n in has) continue
            if (n in hollow) { print "increment " n " (" name[n] ") states a **Verification:** or **Manual:** field with no content"; exit }
            print "increment " n " (" name[n] ") has neither a **Verification:** nor a **Manual:** field"; exit
        }
        for (n in addcount) {
            if (addfields[n] != 1) { print "the addendum dated " lastadd[n] " for increment " n " restates no **Verification:** or **Manual:** field"; exit }
        }
    }
' "$STREAM")"

case "$MODE" in
check)
    printf 'increments: %s\n' "$INCREMENTS"
    printf 'addenda:    %s\n' "$ADDENDA"
    [ -z "$PROBLEM" ] || report "invalid" "$PROBLEM"
    [ "$INCREMENTS" -gt 0 ] || report "invalid" "the plan has no increments under ## Increments"
    report "ok" "$INCREMENTS increment(s) and $ADDENDA addendum(s), every increment verifiable"
    ;;

criteria)
    if [ -n "$PROBLEM" ]; then
        printf 'criteria:   %s\n' "0"
        printf 'manual:     %s\n' "0"
        report "invalid" "$PROBLEM"
    fi
    mkdir -p "$(dirname "$OUT")" "$(dirname "$MANUAL_OUT")"
    # The last SUBSTANTIVE FIELD for a (number, kind) pair wins: an addendum
    # restates. Skipping a hollow one is unreachable while the validation above
    # holds -- it is what keeps the two honest if that ever loosens.
    awk -F'\t' -v out="$OUT" -v manual_out="$MANUAL_OUT" '
        $1 == "INC"   { order[++count] = $2; name[$2] = $3; next }
        $1 == "FIELD" { if ($4 == "1") text[$2 SUBSEP $3] = $5; next }
        END {
            print "# Verification criteria" > out
            print "" > out
            print "# Manual verification items" > manual_out
            print "" > manual_out
            n = 0; m = 0
            for (i = 1; i <= count; i++) {
                inc = order[i]
                if ((inc SUBSEP "verification") in text) {
                    n++
                    printf "%d. Increment %s (%s): %s\n", n, inc, name[inc], text[inc SUBSEP "verification"] > out
                }
                if ((inc SUBSEP "manual") in text) {
                    n++; m++
                    printf "%d. MANUAL — Increment %s (%s): %s\n", n, inc, name[inc], text[inc SUBSEP "manual"] > out
                    printf "%d. Increment %s (%s): %s\n", m, inc, name[inc], text[inc SUBSEP "manual"] > manual_out
                }
            }
            if (m == 0) print "_(none)_" > manual_out
            printf "%d\n%d\n", n, m
        }
    ' "$STREAM" >"$TSF_TMP/counts"
    CRITERIA="$(sed -n 1p "$TSF_TMP/counts")"
    MANUAL="$(sed -n 2p "$TSF_TMP/counts")"
    printf 'criteria:   %s\n' "$CRITERIA"
    printf 'manual:     %s\n' "$MANUAL"
    [ "$CRITERIA" -gt 0 ] || report "invalid" "the plan yielded no criteria at all"
    report "ok" "wrote $CRITERIA criteria to $OUT and $MANUAL manual item(s) to $MANUAL_OUT"
    ;;
esac
