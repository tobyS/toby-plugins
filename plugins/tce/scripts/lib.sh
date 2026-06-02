#!/bin/bash

# Shared helpers for the tce ticket scripts.
#
# These scripts ship inside the tce plugin, so they cannot assume their own
# location relates to the project. The project root is wherever Claude Code is
# running; the ticket prefix is read from the project-local config that
# /tce:init creates.

# Resolve the project root: prefer the hook-provided CLAUDE_PROJECT_DIR,
# fall back to the current working directory (Claude runs Bash from there).
tce_project_root() {
    printf '%s\n' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

# Print the configured ticket prefix, or nothing if the project is not set up.
# Config format (.claude/tce/config) is a simple shell file: TICKET_PREFIX=MYAPP
tce_ticket_prefix() {
    local config
    config="$(tce_project_root)/.claude/tce/config"
    if [ -f "$config" ]; then
        # shellcheck disable=SC1090
        . "$config"
    fi
    printf '%s\n' "${TICKET_PREFIX:-}"
}
