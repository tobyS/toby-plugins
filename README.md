# toby-plugins — a Claude Code marketplace provided by rent-the-toby.com

A catalog of Claude Code plugins from [rent-the-toby.com](https://rent-the-toby.com).
Add the marketplace once, then install any of the plugins below.

## Plugins

| Plugin | Description | Docs |
|--------|-------------|------|
| `tce` | Context-engineering development workflow (**ticket → research → plan → implement**), plus review, discussion, and design-exploration commands and a set of research subagents. | [plugins/tce/README.md](plugins/tce/README.md) |

## Add the marketplace

```bash
# Add the marketplace (once per machine). A git URL or local path also work.
/plugin marketplace add tobyS/toby-plugins
```

Then install a plugin from it — see each plugin's docs for the exact command (e.g.
[`tce`](plugins/tce/README.md#install)):

```bash
/plugin install tce@toby-plugins
```

## Update

```bash
/plugin marketplace update toby-plugins
```

Installed plugins move to a new version when you refresh the marketplace.

## Development

This section is for developers working on the plugins in this repository; users
installing a plugin don't need any of it.

> **Two names, kept distinct:** `toby-plugins` is the **marketplace** (the catalog you
> add); a plugin (e.g. `tce`) is **what you install** from it, using
> `<plugin>@toby-plugins`.

`tobyS/toby-plugins` is the repo's GitHub location (owner + repo). The repo name
matches the marketplace `name` in `.claude-plugin/marketplace.json` (`toby-plugins`)
by design, so the same string appears in both `marketplace add …/toby-plugins` and in
`install <plugin>@toby-plugins`.

### Repository layout

This is a **monorepo marketplace**: the marketplace lives at the repo root and lists
plugins that live under `plugins/`. Today there's one plugin (`tce`); adding another
is a new `plugins/<name>/` directory plus an entry in `marketplace.json`.

```
.claude-plugin/marketplace.json   # the marketplace (name: toby-plugins) — lists the plugins
plugins/
└── tce/                          # the tce plugin (CLAUDE_PLUGIN_ROOT points here once installed)
    ├── .claude-plugin/plugin.json  # plugin manifest (name: tce, version)
    ├── README.md                   # the tce plugin docs
    ├── commands/                   # the /tce:* slash commands
    ├── agents/                     # research subagents
    ├── hooks/hooks.json            # ticket-status PostToolUse hooks
    ├── scripts/                    # ticket scripts (lib.sh + next-ticket/ticket/open_tickets + hook scripts)
    └── templates/tce/              # skeletons /tce:init copies into a project (config, profile.md, design-system.md)
```

All plugin-internal references use `${CLAUDE_PLUGIN_ROOT}/...` (the plugin dir), so they
are unaffected by where the plugin sits in the repo.

### Update gating

Updates are gated per plugin by its `version` (in the plugin's `plugin.json`, mirrored
in the marketplace entry), so projects only move when a plugin is bumped.

### Validate & release

```bash
claude plugin validate .                 # validate the marketplace (+ the plugins it lists)
claude plugin validate ./plugins/tce     # validate just the tce plugin
# bump "version" in plugins/tce/.claude-plugin/plugin.json AND the tce entry in
# .claude-plugin/marketplace.json, then:
claude plugin tag ./plugins/tce          # create the tce--v<version> release tag
```

## License

Provided as-is. Adapt freely to your needs.
