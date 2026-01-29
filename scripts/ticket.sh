#!/bin/bash

# Find all documents in thoughts/ that contain a ticket number in their filename
# Usage: ./scripts/ticket.sh PROJ-0001

# =============================================================================
# CONFIGURATION: Set your ticket prefix here
# =============================================================================
TICKET_PREFIX="PROJ"  # Change this to your project's prefix (e.g., "MYAPP", "ORD")
# =============================================================================

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <ticket-number>"
    echo "Example: $0 ${TICKET_PREFIX}-0001"
    exit 1
fi

TICKET="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
THOUGHTS_DIR="$PROJECT_ROOT/thoughts"

if [ ! -d "$THOUGHTS_DIR" ]; then
    echo "Error: thoughts directory not found at $THOUGHTS_DIR"
    exit 1
fi

find "$THOUGHTS_DIR" -type f -name "*${TICKET}*" | sort
