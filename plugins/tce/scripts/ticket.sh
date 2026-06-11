#!/bin/bash

# Find all documents in thoughts/ that contain a ticket ID in their filename.
# Usage: ticket.sh <ticket-id>
#
# The ticket ID is whatever canonical form the project's ticket system uses
# (see .claude/tce/tickets.md), e.g. MYAPP-0042 or GH-123 — this script just
# globs thoughts/ for it.
#
# The project root is resolved from the project (see lib.sh), not from this
# script's location — it ships inside the tce plugin.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

if [ -z "$1" ]; then
    echo "Usage: $0 <ticket-id>"
    echo "Example: $0 MYAPP-0001"
    exit 1
fi

TICKET="$1"
THOUGHTS_DIR="$(tce_project_root)/thoughts"

if [ ! -d "$THOUGHTS_DIR" ]; then
    echo "Error: thoughts directory not found at $THOUGHTS_DIR" >&2
    exit 1
fi

find "$THOUGHTS_DIR" -type f -name "*${TICKET}*" | sort
