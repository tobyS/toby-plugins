#!/bin/bash

# Post-hook for git add: Check ticket status and remind Claude to update if needed
#
# This hook receives JSON input via stdin with the following structure:
# { "tool_name": "Bash", "tool_input": { "command": "..." }, "tool_response": {...} }
#
# To communicate feedback to Claude, we must use JSON output with additionalContext.
# Plain echo with exit 0 is NOT shown to Claude.

# =============================================================================
# CONFIGURATION: Set your ticket prefix here
# =============================================================================
TICKET_PREFIX="PROJ"  # Change this to your project's prefix (e.g., "MYAPP", "ORD")
# =============================================================================

# Debug logging
DEBUG_LOG="/tmp/claude-hook-bash-ticket.log"
log() { echo "[bash-ticket] $(date '+%H:%M:%S') $1" >> "$DEBUG_LOG"; }

log "=== START ==="

# Read hook input from stdin
INPUT=$(cat)
log "Read input, length: ${#INPUT}"

set -e
trap 'log "ERROR at line $LINENO: $BASH_COMMAND (exit $?)"' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TICKETS_DIR="$PROJECT_ROOT/thoughts/shared/tickets"

# Extract command from JSON
log "Extracting command with jq..."
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
log "COMMAND: $COMMAND"

# Only process git add commands
if [[ ! "$COMMAND" =~ ^git\ add ]]; then
    log "Not a git add command, exiting"
    exit 0
fi

log "Processing git add command"

# Build ticket pattern from prefix
TICKET_PATTERN="${TICKET_PREFIX}-[0-9]+"

# Find ticket IDs referenced in staged files (by path)
log "Getting staged files..."
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)
log "Staged files: $STAGED_FILES"

FOUND_TICKETS=""
for file in $STAGED_FILES; do
    if [[ "$file" =~ (${TICKET_PREFIX}-[0-9]+) ]]; then
        TICKET_ID="${BASH_REMATCH[1]}"
        if [[ ! "$FOUND_TICKETS" =~ "$TICKET_ID" ]]; then
            FOUND_TICKETS="$FOUND_TICKETS $TICKET_ID"
        fi
    fi
done
log "Tickets from staged files: '$FOUND_TICKETS'"

# Also check recent commits for ticket context
if [ -z "$FOUND_TICKETS" ]; then
    log "No tickets in staged files, checking recent commits..."
    FOUND_TICKETS=$(git log --oneline -10 2>/dev/null | grep -oE "${TICKET_PATTERN}" | sort -u | tr '\n' ' ')
    log "Tickets from recent commits: '$FOUND_TICKETS'"
fi

# Collect feedback messages
log "Collecting feedback for tickets..."
FEEDBACK=""
for TICKET_ID in $FOUND_TICKETS; do
    log "Processing ticket: $TICKET_ID"
    TICKET_FILE=$(find "$TICKETS_DIR" -name "*${TICKET_ID}*" -type f 2>/dev/null | head -1)
    if [ -n "$TICKET_FILE" ]; then
        log "Found ticket file: $TICKET_FILE"
        STATUS=$(grep -m1 '^\*\*Status:\*\*' "$TICKET_FILE" | sed 's/\*\*Status:\*\* //')
        log "Ticket status: '$STATUS'"

        if [ "$STATUS" = "Open" ]; then
            FEEDBACK="${FEEDBACK}Ticket $TICKET_ID has status 'Open'. If you're working on this ticket, update status to 'In Progress'. If this commit completes the ticket, update to 'Done'. Remember to git add the ticket file after updating!\n"
        elif [ "$STATUS" = "In Progress" ]; then
            FEEDBACK="${FEEDBACK}Ticket $TICKET_ID has status 'In Progress'. If this commit completes the ticket, update status to 'Done'. Remember to git add the ticket file after updating!\n"
        fi
    else
        log "No ticket file found for $TICKET_ID"
    fi
done

# Output feedback as JSON with additionalContext so Claude sees it
if [ -n "$FEEDBACK" ]; then
    log "Outputting feedback to Claude"
    # Escape the feedback for JSON (handle newlines and quotes)
    ESCAPED_FEEDBACK=$(echo -e "$FEEDBACK" | jq -Rs '.')
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": $ESCAPED_FEEDBACK
  }
}
EOF
else
    log "No feedback to output"
fi

log "=== END (success) ==="
exit 0
