# tsf — Toby Software Factory

An agentic software factory for a single-engineer project. tsf works a
GitHub-issue backlog: it picks the most important ready ticket, advances it
exactly one work step per cycle in a fresh agent context, talks to you
asynchronously on the issue, and keeps every substantive artifact (spec,
research, plan, journal) as a versioned file on the ticket branch.

The full design is in [`DESIGN.md`](DESIGN.md).

## Slice 1 (0.1.0) scope

tsf is released in three slices. This version is slice 1:

- **Works:** `/tsf:init` (project setup), `/tsf:spec` (authoring a ticket),
  and `/tsf:cycle` for triage, research and planning — a released ticket gets
  researched and ends with a plan summary for you to approve on the issue.
- **Not implemented yet:** implementation, verification, the gates, the
  dossier, review handling (slice 2) and landing (slice 3). A ticket that
  reaches `tsf:implement` is reported by `/tsf:cycle` as "not implemented in
  this slice" and left alone.

## Install

```
/plugin marketplace add tobyS/toby-plugins
/plugin install tsf@toby-plugins
```
