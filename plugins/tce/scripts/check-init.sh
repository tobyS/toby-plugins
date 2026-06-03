#!/bin/bash

# SessionStart hook: nudge an uninitialized project toward /tce:init.
#
# tce keeps all project-specific config in .claude/tce/ (created by /tce:init).
# Until that exists, the workflow commands can't read the project profile or
# resolve the ticket prefix. This hook detects that state at session start and
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

# Already initialized? Stay silent.
CONFIG="$(tce_project_root)/.claude/tce/config"
if [ -f "$CONFIG" ]; then
    log "Project already initialized ($CONFIG), exiting"
    exit 0
fi

log "Project not initialized, emitting init nudge"

read -r -d '' CONTEXT <<'EOF'
The **tce** context-engineering workflow plugin is installed, but this project is
not initialized yet (no `.claude/tce/config` found). Before doing other work,
introduce tce to the user and offer to set it up:

- Briefly explain what tce is: a ticket → research → plan → implement workflow,
  plus review, discuss, and design-exploration commands. Project specifics
  (stack, test/lint/typecheck commands, ticket prefix) live in `.claude/tce/`,
  which `/tce:init` creates by analyzing the repo and agreeing a profile with the
  user.
- Strongly advise running `/tce:init` to set the project up, and offer to run it
  now. Run `/tce:init` only after the user confirms; it analyzes the project and
  asks before writing any files.
- If the user declines, continue normally — the other tce commands will keep
  reminding them until the project is initialized.
EOF

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
