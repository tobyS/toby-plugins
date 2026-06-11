#!/bin/bash

# Shared helpers for the tmt ticket scripts.
#
# These scripts ship inside the tmt plugin, so they cannot assume their own
# location relates to the project. The project root is wherever Claude Code is
# running; the ticket prefix is read from the project-local config that
# /tmt:init creates.

# Resolve the project root: prefer the hook-provided CLAUDE_PROJECT_DIR,
# fall back to the current working directory (Claude runs Bash from there).
tmt_project_root() {
    printf '%s\n' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

# Print the configured ticket prefix, or nothing if the project is not set up.
# Config format (.claude/tmt/config) is a simple shell file: TICKET_PREFIX=MYAPP
#
# Falls back to the legacy tce location (.claude/tce/config) — the ticket system
# lived inside the tce plugin before it was split out into tmt — so projects set
# up by an old /tce:init keep working until /tmt:init migrates them.
tmt_ticket_prefix() {
    local config root
    root="$(tmt_project_root)"
    for config in "$root/.claude/tmt/config" "$root/.claude/tce/config"; do
        if [ -f "$config" ]; then
            # shellcheck disable=SC1090
            . "$config"
            if [ -n "${TICKET_PREFIX:-}" ]; then
                break
            fi
        fi
    done
    printf '%s\n' "${TICKET_PREFIX:-}"
}
