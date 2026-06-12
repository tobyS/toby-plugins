#!/bin/bash

# SessionStart hook: nudge an uninitialized project toward /tce:init.
#
# tce keeps all project-specific config in .claude/tce/ (created by /tce:init).
# Until that exists, the workflow commands can't read the project profile or
# the ticket-system config. This hook detects that state at session start and
# feeds Claude context asking it to introduce tce and offer to run /tce:init.
#
# A SessionStart hook cannot invoke a slash command itself — it can only return
# context via hookSpecificOutput.additionalContext. So this nudges Claude; the
# actual /tce:init still runs interactively (and asks before writing files).
#
# Once the project is initialized this hook is a silent no-op, so it stops
# nagging after the first setup. There is no "plugin installed" event in Claude
# Code; SessionStart + this guard is the closest equivalent — the first session
# after install is uninitialized, so the prompt fires then. (The plugin's
# userConfig also greets the user once at enable time; this hook is the ongoing,
# project-state-aware nudge that also covers fresh clones.)
#
# Argument $1 is the plugin's `show_setup_reminders` user-config value, passed in
# from hooks.json as ${user_config.show_setup_reminders}. When the user has
# turned reminders off it is the literal string "false" and we stay silent. Any
# other value (true, empty, or an un-substituted placeholder on older Claude
# Code) is treated as "reminders on".

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# Optional debug logging, off by default (set TCE_HOOK_DEBUG=1 to enable).
if [ -n "${TCE_HOOK_DEBUG:-}" ]; then
    DEBUG_LOG="${TMPDIR:-/tmp}/claude-hook-init.log"
    log() { echo "[init] $(date '+%H:%M:%S') $1" >> "$DEBUG_LOG"; }
else
    log() { :; }
fi

log "=== START ==="

# Reminders turned off via plugin user config? Stay silent.
if [ "${1:-}" = "false" ]; then
    log "Setup reminders disabled via user config, exiting"
    exit 0
fi

# Already initialized? Stay silent. profile.md is the marker file — it is the
# first thing /tce:init writes. (tce ≤1.x used .claude/tce/config, which no
# longer exists; old projects also have profile.md, so the guard still holds.)
PROFILE="$(tce_project_root)/.claude/tce/profile.md"
if [ -f "$PROFILE" ]; then
    log "Project already initialized ($PROFILE), exiting"
    exit 0
fi

# Not initialized. Pick the nudge variant: if the project carries the strong
# signature of the original claude-template (the plugins' predecessor) —
# its ticket script plus an un-namespaced workflow command — tailor the
# nudge toward migration instead of a fresh setup.
ROOT="$(tce_project_root)"
if [ -f "$ROOT/scripts/next-ticket.sh" ] && [ -f "$ROOT/.claude/commands/research_codebase.md" ]; then
    log "Template install detected, emitting migration nudge"
    read -r -d '' CONTEXT <<'EOF'
The **tce** context-engineering workflow plugin is installed, and this project
contains an install of the original **claude-template** (un-namespaced
`.claude/commands/*.md`, root `scripts/*.sh`) — the predecessor the plugins
replace. Before doing other work, tell the user this and offer to migrate:

- `/tce:init` detects the template install and migrates it: the established
  ticket prefix is harvested, the plugin config is written (`/tmt:init` handles
  the ticket side), and the superseded template files are removed only after
  an explicit confirmation. Existing tickets, research, and plans under
  `thoughts/shared/` carry over untouched.
- Offer to run `/tce:init` now. Run it only after the user confirms; it
  analyzes the project and asks before writing or deleting any files.
- If the user declines, continue normally — the reminder returns next session.
EOF
else
    log "Project not initialized, emitting init nudge"
    read -r -d '' CONTEXT <<'EOF'
The **tce** context-engineering workflow plugin is installed, but this project is
not initialized yet (no `.claude/tce/profile.md` found). Before doing other work,
introduce tce to the user and offer to set it up:

- Briefly explain what tce is: a ticket → research → plan → implement workflow,
  plus review, discuss, and design-exploration commands. Project specifics
  (stack, test/lint/typecheck commands, ticket system) live in `.claude/tce/`,
  which `/tce:init` creates by analyzing the repo and agreeing a profile with the
  user.
- Strongly advise running `/tce:init` to set the project up, and offer to run it
  now. Run `/tce:init` only after the user confirms; it analyzes the project and
  asks before writing any files.
- If the user declines, continue normally — the other tce commands will keep
  reminding them until the project is initialized.
EOF
fi

# Emit as a single JSON string (newlines escaped) so no jq dependency is needed.
ESCAPED=$(printf '%s' "$CONTEXT" | awk 'BEGIN{ORS="\\n"} {gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); print}')

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$ESCAPED"
  }
}
EOF

log "=== END (success) ==="
exit 0
