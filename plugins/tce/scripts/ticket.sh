#!/bin/bash

# Find all documents in thoughts/ that contain a ticket number in their filename.
# Usage: ticket.sh <PREFIX>-0001
#
# The project root is resolved from the project (see lib.sh), not from this
# script's location — it ships inside the tce plugin.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

if [ -z "$1" ]; then
    PREFIX="$(tce_ticket_prefix)"
    echo "Usage: $0 <ticket-number>"
    echo "Example: $0 ${PREFIX:-PREFIX}-0001"
    exit 1
fi

TICKET="$1"
THOUGHTS_DIR="$(tce_project_root)/thoughts"

if [ ! -d "$THOUGHTS_DIR" ]; then
    echo "Error: thoughts directory not found at $THOUGHTS_DIR" >&2
    exit 1
fi

find "$THOUGHTS_DIR" -type f -name "*${TICKET}*" | sort
