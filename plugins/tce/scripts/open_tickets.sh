#!/bin/bash

# List all open tickets (status: Open or In Progress) with their research & plan files.
# Usage: open_tickets.sh
#
# The ticket prefix and project root are resolved from the project (see lib.sh),
# not from this script's location — it ships inside the tce plugin.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

TICKET_PREFIX="$(tce_ticket_prefix)"
if [ -z "$TICKET_PREFIX" ]; then
    echo "Error: no ticket prefix configured. Run /tce:init to set up this project." >&2
    exit 1
fi

THOUGHTS_DIR="$(tce_project_root)/thoughts"
TICKETS_DIR="$THOUGHTS_DIR/shared/tickets"

if [ ! -d "$TICKETS_DIR" ]; then
    echo "Error: tickets directory not found at $TICKETS_DIR" >&2
    exit 1
fi

# Find all ticket files sorted by ticket number descending
TICKET_FILES=$(find "$TICKETS_DIR" -type f -name "${TICKET_PREFIX}-*.md" | sort -t '-' -k2 -n -r)

if [ -z "$TICKET_FILES" ]; then
    echo "No tickets found"
    exit 1
fi

OPEN_COUNT=0

for TICKET_FILE in $TICKET_FILES; do
    # Extract status from file
    STATUS=$(grep -m1 '^\*\*Status:\*\*' "$TICKET_FILE" | sed 's/\*\*Status:\*\* //')

    # Only show open tickets (Open or In Progress)
    if [ "$STATUS" != "Open" ] && [ "$STATUS" != "In Progress" ]; then
        continue
    fi

    OPEN_COUNT=$((OPEN_COUNT + 1))

    # Extract ticket ID from filename (including optional letter suffix for sub-tickets)
    TICKET_ID=$(basename "$TICKET_FILE" | grep -oE "${TICKET_PREFIX}-[0-9]+[a-z]*")

    # Extract title from first line
    TITLE=$(head -1 "$TICKET_FILE" | sed 's/^# //' | sed "s/^$TICKET_ID: //")

    # Extract estimated complexity
    COMPLEXITY=$(grep -m1 '^\*\*Estimated Complexity:\*\*' "$TICKET_FILE" | sed 's/\*\*Estimated Complexity:\*\* //' || echo "Unknown")
    COMPLEXITY="${COMPLEXITY:-Unknown}"

    # Print ticket header
    echo "$TICKET_ID: $TITLE"
    echo "  Status: $STATUS | Complexity: $COMPLEXITY"

    # Find research and plan files (use word boundary pattern to avoid partial matches)
    RESEARCH_FILE=$(find "$THOUGHTS_DIR/shared/research" -type f -name "*${TICKET_ID}-*" -o -name "*${TICKET_ID}.*" 2>/dev/null | head -1)
    PLAN_FILE=$(find "$THOUGHTS_DIR/shared/plans" -type f -name "*${TICKET_ID}-*" -o -name "*${TICKET_ID}.*" 2>/dev/null | head -1)

    # Print file status
    if [ -n "$RESEARCH_FILE" ]; then
        echo "  RESEARCH: ✅ $(basename "$RESEARCH_FILE")"
    else
        echo "  RESEARCH: ❌"
    fi

    if [ -n "$PLAN_FILE" ]; then
        echo "  PLAN:     ✅ $(basename "$PLAN_FILE")"
    else
        echo "  PLAN:     ❌"
    fi

    echo ""
done

if [ $OPEN_COUNT -eq 0 ]; then
    echo "No open tickets found"
else
    echo "---"
    echo "Total open tickets: $OPEN_COUNT"
fi
