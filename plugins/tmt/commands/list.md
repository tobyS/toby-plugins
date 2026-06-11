---
description: List open tickets (status Open or In Progress), with their tce research/plan documents if the project uses tce.
---

# List Open Tickets

Run the shipped lister and present its output:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/open_tickets.sh"
```

- Show the tickets exactly as listed (ID, title, status, complexity). The
  RESEARCH/PLAN lines refer to the tce workflow's documents in
  `thoughts/shared/research/` and `thoughts/shared/plans/`; if the project
  doesn't use tce, omit those lines from your summary instead of explaining ❌
  marks.
- If the script errors with "no ticket prefix configured", tell the user to run
  `/tmt:init` first.
- If the user asked for something more specific (e.g. only In Progress, or a
  particular topic), filter the script's output accordingly when presenting it.
