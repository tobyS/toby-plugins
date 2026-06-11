#!/bin/bash

# PostToolUse hook for Edit/Write: validate ticket status is a valid value.
#
# Receives JSON via stdin:
# { "tool_name": "Edit|Write", "tool_input": { "file_path": "...", "new_string": "..." }, ... }
#
# Valid statuses: Open, In Progress, Done, Rejected
#
# The ticket prefix and project root come from the project (see lib.sh); this
# script ships inside the tmt plugin. If the project isn't set up (no prefix),
# the hook is a silent no-op.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# Debug logging
DEBUG_LOG="${TMPDIR:-/tmp}/claude-hook-tmt-ticket.log"
log() { echo "[ticket] $(date '+%H:%M:%S') $1" >> "$DEBUG_LOG"; }

# Log immediately on start with working directory
log "=== START (cwd: $(pwd)) ==="

# Read stdin first (before set -e in case cat fails on empty input)
INPUT=$(cat) || INPUT=""
log "Read input, length: ${#INPUT}"

set -e
trap 'log "ERROR at line $LINENO: $BASH_COMMAND (exit $?)"' ERR

TICKET_PREFIX="$(tmt_ticket_prefix)"
if [ -z "$TICKET_PREFIX" ]; then
    log "No ticket prefix configured, exiting (project not set up)"
    exit 0
fi

# Extract file_path and new_string from JSON
log "Extracting file_path with jq..."
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
log "FILE_PATH: $FILE_PATH"

NEW_STRING=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty')
log "NEW_STRING length: ${#NEW_STRING}"

# Exit early if no file path
if [ -z "$FILE_PATH" ]; then
    log "No file path, exiting"
    exit 0
fi

# Only check ticket files in thoughts/shared/tickets/
if ! [[ "$FILE_PATH" =~ thoughts/shared/tickets/${TICKET_PREFIX}-.*\.md$ ]]; then
    log "Not a ticket file, exiting"
    exit 0
fi

# Check if the edit contains a status line
if ! echo "$NEW_STRING" | grep -qE '^\*\*Status:\*\*'; then
    log "No status line in edit, exiting"
    exit 0
fi

# Extract the status value from the new string
STATUS=$(echo "$NEW_STRING" | grep -oE '\*\*Status:\*\* [A-Za-z ]+' | sed 's/\*\*Status:\*\* //')
log "Extracted STATUS: '$STATUS'"

# Exit if we couldn't extract a status
if [ -z "$STATUS" ]; then
    log "Could not extract status, exiting"
    exit 0
fi

# Valid statuses
VALID_STATUSES="Open|In Progress|Done|Rejected"

# Check if status is valid
if ! echo "$STATUS" | grep -qE "^($VALID_STATUSES)$"; then
    log "Invalid status: '$STATUS'"
    FEEDBACK="INVALID TICKET STATUS: '$STATUS' is not a valid status.

Valid statuses are:
- Open: Ticket created, not yet started
- In Progress: Currently being worked on
- Done: Work completed
- Rejected: Won't be done (duplicate, out of scope, won't fix)

Please fix the status in $FILE_PATH"
    ESCAPED_FEEDBACK=$(echo "$FEEDBACK" | jq -Rs '.')
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": $ESCAPED_FEEDBACK
  }
}
EOF
fi

log "=== END (success) ==="
exit 0
