#!/bin/bash

# Shared helpers for the tce scripts.
#
# These scripts ship inside the tce plugin, so they cannot assume their own
# location relates to the project. The project root is wherever Claude Code is
# running.

# Resolve the project root: prefer the hook-provided CLAUDE_PROJECT_DIR,
# fall back to the current working directory (Claude runs Bash from there).
tce_project_root() {
    printf '%s\n' "${CLAUDE_PROJECT_DIR:-$PWD}"
}
