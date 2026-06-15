#!/bin/bash

# Print the valid tmt ticket statuses, one per line — a thin CLI over
# tmt_valid_statuses in lib.sh so commands (/tmt:update) and humans can query the
# enum without duplicating it. lib.sh is the single source of truth.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

tmt_valid_statuses
