#!/bin/bash

# Generate the next available ticket number
# Usage: ./scripts/next-ticket.sh
#
# Scans the tickets directory for all [PREFIX]-XXXX files and returns
# the next available number. Ignores sub-tickets ([PREFIX]-XXXXa, etc.)

# =============================================================================
# CONFIGURATION: Set your ticket prefix here
# =============================================================================
TICKET_PREFIX="PROJ"  # Change this to your project's prefix (e.g., "MYAPP", "ORD")
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TICKETS_DIR="$PROJECT_ROOT/thoughts/shared/tickets"

if [ ! -d "$TICKETS_DIR" ]; then
    echo "Error: tickets directory not found at $TICKETS_DIR" >&2
    exit 1
fi

# Find the highest main ticket number (ignore sub-tickets like PROJ-0057a)
# Pattern: [PREFIX]-XXXX.md (exactly 4 digits followed by .md)
HIGHEST=$(find "$TICKETS_DIR" -type f -name "${TICKET_PREFIX}-[0-9][0-9][0-9][0-9]*.md" \
    | xargs -n1 basename 2>/dev/null \
    | grep -oE "${TICKET_PREFIX}-[0-9]{4}" \
    | sort -t'-' -k2 -n \
    | uniq \
    | tail -1 \
    | grep -oE '[0-9]+' || echo "")

if [ -z "$HIGHEST" ]; then
    # No tickets found, start at 0001
    NEXT=1
else
    NEXT=$((10#$HIGHEST + 1))
fi

# Format with leading zeros (4 digits)
printf "%s-%04d\n" "$TICKET_PREFIX" "$NEXT"
