# toby-plugins

A Claude Code plugin marketplace: a context-engineering development workflow
(**`tce`**), a Git-tracked markdown ticket tracker (**`tmt`**), an autonomous
convergence loop for greenfield projects (**`tle`**), and an agentic software
factory over a GitHub-issue backlog (**`tsf`**).

Add the marketplace once, then install whichever plugins you need into any project.
They are built for everyday Claude Code work — `tce` gives Claude the right context at
each step of a task, `tmt` keeps your tickets as plain files in the repo, `tle`
drives a new project toward a machine-checkable goal, and `tsf` works a backlog
of GitHub issues to merged pull requests with you as the reviewer.

> **Built by Toby.** These plugins come out of my daily practice helping
> engineering teams turn experimental AI use into structured, sustainable
> workflows. Need a sparring partner for the hard technical and AI-adoption calls?
> Find me at [rent-the-toby.com](https://rent-the-toby.com).

## Plugins

| Plugin | What it does | Docs |
|--------|-------------|------|
| `tce` | Context-engineering development workflow (**ticket → research → plan → implement**), plus review, discussion, and design-exploration commands and a set of research subagents. Works with any ticket system (tmt, GitHub Issues, Jira, Linear, custom). | [plugins/tce/README.md](plugins/tce/README.md) |
| `tmt` | Toby Markdown Tickets — a lightweight, Git-tracked ticket tracker: tickets as markdown files in your repo, with guided creation, sequential numbering, and status-lifecycle hooks. Works standalone; `tce`'s native ticket backend. | [plugins/tmt/README.md](plugins/tmt/README.md) |
| `tle` | Toby Loop Engineering — an autonomous convergence loop: define a machine-checkable goal, then iterate **verify → spec → implement** until every checklist item verifiably passes. Greenfield-first, with file-only handoffs as the audit trail. | [plugins/tle/README.md](plugins/tle/README.md) |
| `tsf` | Toby Software Factory — an agentic factory over a GitHub-issue backlog: it advances one ticket **one step per cycle** in a fresh context, from spec through research, plan, implementation and verification to a reviewed pull request, and lands it after your approval. You write specs, answer batched questions and review — all on the issue. | [plugins/tsf/README.md](plugins/tsf/README.md) |

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

## Contributing

Want to work on the plugins themselves? See [CONTRIBUTING.md](CONTRIBUTING.md) for the
repository layout, how to validate changes, and the release flow.

## License

Provided as-is. Adapt freely to your needs.
