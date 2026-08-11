# From tce to a Software Factory — Research & Review

**Date:** 2026-07-07
**Scope:** How software factories are built today (2025/26), an architectural
analysis of the tce plugin, and reasoning about how tce's ideas could seed a
software factory.

## TLDR

Modern "software factories" — in the 2025/26 AI-native sense — converge on
exactly the architecture tce already implements at single-ticket scale: typed
artifact stages (spec → plan → implement), durable git-tracked context, human
gates at the plan, and isolated verification agents. What separates tce from a
factory is not process design but **transport and scale**: automated intake,
parallel unattended execution, async human checkpoints, PR-based delivery with
machine merge gates, and telemetry. tce's best ideas (the artifact chain, the
context-starved compliance checker, the process/config split, graduated
autonomy) are precisely the pieces the factory literature identifies as hardest
to get right — so it's a strong seed.

## 1. How software factories are built today

The term now has two meanings that are converging.

### 1a. Platform-engineering flavor

The classic/enterprise meaning: an organization plus a standardized platform
that turns software delivery into a repeatable, secured pipeline rather than
artisanal per-team effort.

- Canonical instances: the US DoD's factories — [Kessel Run](https://en.wikipedia.org/wiki/Kessel_Run)
  (USAF, 2017) and [Platform One](https://govciomedia.com/platform-one-tackles-next-phase-in-software-delivery/)
  with its hardened substrate (Iron Bank vetted container registry, Big Bang
  Kubernetes DevSecOps baseline).
- The civilian cousin is **platform engineering**: internal developer platforms
  (Backstage as the dominant model — service catalog plus scaffolder templates)
  offering "golden paths" (Spotify) / "paved roads" (Netflix), so the sanctioned
  way to build and ship is also the easiest way
  ([Red Hat](https://www.redhat.com/en/topics/platform-engineering/golden-paths),
  [platformengineering.org](https://platformengineering.org/blog/what-are-golden-paths-a-guide-to-streamlining-developer-workflows)).
- Measured with DORA metrics; security shifted into the pipeline (DevSecOps,
  continuous ATO) rather than end-stage accreditation.
- Notably, the pure DoD factory model is in crisis: factories became
  bottlenecked institutions, and 2025 saw the Air Force restructure several
  ([Average Geniuses](https://www.averagegeniuses.com/the-end-of-the-assembly-line-why-the-dod-software-factory-era-is-over/),
  [War on the Rocks](https://warontherocks.com/2025/10/the-air-force-is-kneecapping-software-innovation/)).
  The surviving thesis: the value sits in the platform, not the coding house.

### 1b. AI-agentic flavor

The new meaning: "an agentic system that can receive a specification and
autonomously produce working, deployed, tested software" with humans defining
intent and gating outcomes
([Mager](https://www.mager.co/blog/2026-03-19-software-factory/),
[BCG Platinion](https://www.bcgplatinion.com/insights/the-agentic-software-factory),
[Factory.ai](https://factory.ai/news/software-factory)). Independent sources
converge on a seven-layer reference architecture:

1. **Intake** — signals (issues, tickets, Slack threads, incidents, failing
   tests) normalized into structured, agent-consumable tasks.
2. **Spec-driven development** — a durable written specification precedes code.
   [GitHub Spec Kit](https://github.github.com/spec-kit/) (spec → plan → tasks
   → implement, each phase human-approved, plus a per-project "constitution")
   and [Amazon Kiro](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
   (requirements.md / design.md / tasks.md persisted in-repo) made "no code
   without an approved written spec" mainstream.
3. **Orchestrator / control plane** — assigns work to agent fleets, routes
   models, prevents conflicts, audits everything
   ([GitHub Agent HQ](https://github.blog/news-insights/company-news/welcome-home-agents/),
   Factory.ai's Router).
4. **Role-specialized execution agents** — planner, coder, reviewer, tester,
   deployer; noisy work pushed into subagents that return compacted summaries
   ([Anthropic on context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)).
5. **Durable context artifacts** — the factory's tooling is largely versioned
   markdown: constitutions, AGENTS.md/CLAUDE.md, research docs, plans, ADRs.
   [HumanLayer's ACE-FCA](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md)
   is the clearest practitioner statement: research → plan → implement
   ("frequent intentional compaction"), each phase writing a compacted artifact
   that seeds a fresh context window, human review concentrated on the plan.
6. **Layered machine verification** — scenario tests derived from business
   requirements, static analysis, architecture-conformance checks, adversarial
   red-team agents, AI merge gates
   ([Greptile](https://www.greptile.com/), CodeRabbit). Widely called the
   bottleneck of the whole field.
7. **Delivery + feedback** — agents propose draft PRs but structurally cannot
   merge their own work ([GitHub Copilot coding agent](https://github.blog/news-insights/product-news/github-copilot-meet-the-new-coding-agent/)
   is the archetype: issue-assignment → Actions VM → draft PR on a `copilot/*`
   branch, human approval required before CI even runs); production signals
   feed back into intake.

Concrete named systems: Platform One / Big Bang / Iron Bank, Kessel Run,
Backstage, GitHub Spec Kit, Amazon Kiro, Factory.ai's Droids (Code / Knowledge
/ Reliability Droids, HyperCode codebase graph, multi-agent "Missions"),
GitHub Copilot coding agent + Agent HQ, the background-agent fleet products
(Devin, OpenAI Codex cloud, Google Jules, Cursor background agents), HumanLayer
ACE-FCA, and AI review gates (Greptile, CodeRabbit).

### 1c. What makes it a "factory" vs. developers using AI tools

1. Standardized stages with typed, durable, reviewable artifacts — not ad-hoc
   chat sessions.
2. Delegation, not collaboration: the unit of work is an assigned task
   returning a reviewable diff/PR; humans move to the outer loop.
3. Explicit trust gates and division of labor: plan approval, human-gated CI,
   agents structurally unable to merge their own work.
4. Repeatability via codified, versioned context (the AI-era golden path).
5. Telemetry and audit: every agent action logged; DORA metrics extended with
   defect-escape and trust measures.
6. Closed feedback loops: monitoring, incidents, and failing tests re-enter
   intake automatically.

### 1d. Documented failure modes

- **AI amplifies existing dysfunction.** The [2025 DORA report](https://dora.dev/dora-report-2025/)
  found AI is an amplifier: without strong automated testing and fast feedback
  loops, increased change volume produces instability, not throughput.
- **Rubber-stamp review.** Bryan Finster: "If your average review time for AI
  PRs matches your average for human PRs, you are not reviewing — you are
  rubber-stamping" ([AI Broke Your Code Review](https://bryanfinster.substack.com/p/ai-broke-your-code-review-heres-how)).
  Large AI diffs past ~400 lines effectively get no review.
- **Elevated defect/security rates** in AI PRs (industry figures: ~1.7x more
  defects; 45% introduce at least one OWASP Top 10 issue — Veracode 2025).
- **Spec drift and scope drift** — the hardest failures live in the gap between
  what the spec said and what the model understood
  ([Augment Code on harness engineering](https://www.augmentcode.com/guides/harness-engineering-ai-coding-agents)).
- **The 80% problem** — agents ship the visible 80% (CRUD, standard patterns,
  passing tests) while systematically omitting the invisible 20%: NFRs, failure
  handling, architectural consistency
  ([Augment Code](https://www.augmentcode.com/guides/the-80-percent-problem-ai-agents-technical-debt)).
- **Verification-agent isolation matters.** A recurring practitioner lesson: a
  checker agent that sees the implementer's reasoning will rationalize gaps;
  effective gates feed the verifier only the criteria and the diff.

### 1e. Where the field is heading

1. Convergence: platform engineering becomes the substrate for agent fleets
   ("IDP for agents").
2. Spec as the primary artifact; code as a build output of the spec.
3. From copilots to fleets: the scaling unit is agents-per-operator.
4. Verification is the bottleneck and the moat — the most investment goes into
   layered machine verification, because human review does not scale to factory
   throughput.
5. Continual learning loops: proprietary organizational context as the durable
   asset.

Caveat: headline throughput claims (Factory.ai's "4-month migration in 3.5
days", HumanLayer's "35k lines in 7 hours") come from vendors or consultancies
and lack independent verification.

## 2. What tce actually is, architecturally

Read end to end (README, the four core workflow commands, the composites
`/tce:work` and `/tce:quickfix`, `/tce:review`, the `plan-compliance-checker`
agent, and the config/document templates), tce is a **single-ticket software
factory cell** built on five design ideas:

1. **A typed artifact chain in git.** Ticket (WHAT/WHY, testable acceptance
   criteria, explicit out-of-scope) → research doc (documentarian-only,
   file:line evidence, impact analysis, defect mechanism) → phased plan
   (per-phase Automated/Manual success criteria) → status file (phases, issues,
   per-phase commits, base commit). Each is written from a template read at
   point of use, committed as a checkpoint, and — the TP-0013 rule —
   **unconditionally re-read in chain order by every consuming step**,
   defeating context fade. This is ACE-FCA's "frequent intentional compaction"
   independently arrived at, with stricter re-read discipline than most
   published setups.

2. **Attention isolation by role.** Research subagents are hard-constrained to
   documenting ("your only job is to describe what exists"); the
   plan-compliance-checker receives *only* the numbered criteria and the diff —
   never the ticket, plan, or the reasoning that produced the code — and must
   return one evidenced verdict per criterion, with "not met" blocking the
   ticket's done transition. That context-starved verifier is exactly the
   anti-rationalization gate the factory literature says is essential and
   rarely built.

3. **Process/config separation.** The workflow is centrally versioned and
   project-agnostic; everything project-specific lives in `.claude/tce/`
   (profile.md = stack/commands/conventions/commit convention, tickets.md =
   ticket-system adapter with envelope/payload split and an explicit autonomy
   policy). This is the golden-path idea applied to agent workflows: one paved
   road, per-project parameterization, updated centrally.

4. **Human gates at maximum-leverage points.** Plan approval in the manual
   flow; in `/tce:work` exactly two possible interactions — ticket sufficiency
   and the open-questions checkpoint between research and planning. Humans
   decide *intent and trade-offs*; they never babysit generation. This matches
   where the field says human attention should concentrate.

5. **Graduated autonomy.** Ticket-size assessment routes ceremony (compressed
   vs full discussion); `/tce:quickfix` (fully autonomous, refuses if policy
   forbids ticket creation, aborts if the fix turns out non-small) <
   `/tce:work` (one checkpoint) < manual chain. Autonomy is a per-project,
   policy-controlled dial — plus self-maintenance (drift detection in research
   → `/tce:refresh`).

## 3. From tce to a software factory

Mapping tce onto the seven-layer reference architecture: layers 2, 4, and 5
are essentially done; 6 is seeded; 1, 3, and 7 are absent by design. The
interesting reasoning is what carries over, what must change transport, and
what's genuinely missing.

### Carries over directly

1. **The artifact chain is the factory's work-in-progress inventory.** A
   factory needs every stage's output to be inspectable and resumable by a
   different worker (human or agent); tce's committed docs plus status files
   with base commits already provide that. Nothing to redesign.
2. **The compliance gate generalizes into the verification layer.** The
   pattern — fresh context, criteria + diff only, evidenced verdicts, blocking
   semantics — extends naturally to a *family* of gates: security checker,
   architecture-conformance checker, regression-scope checker, each
   context-starved the same way. Because `/tce:ticket` enforces testable
   acceptance criteria upfront, criteria are already machine-derivable into
   scenario tests — the input the "verification is the bottleneck" problem
   needs.
3. **profile.md/tickets.md become the factory constitution.** Multi-repo
   factories need per-repo parameterization of one central process; tce
   already has the mechanism, including the autonomy policy knob (whether
   agents may create tickets / transition statuses) — which at factory scale
   becomes the per-repo trust level.

### Must change transport (same design, different medium)

4. **Human checkpoints go async.** `/tce:work`'s open-questions checkpoint
   assumes a human at the terminal. In a factory, the same checkpoint writes
   the questions *back to the ticket* and parks it in a "blocked: needs
   decision" state; the human answers in the ticket system, and the pipeline
   resumes. tce's structure makes this cheap: the checkpoint is already a
   discrete, well-defined phase with batched questions, and tmt already treats
   ticket state as the coordination medium. Same for plan approval: the plan
   doc is already the review surface — it just needs to be reviewable as an
   async artifact (a PR of the plan) instead of a chat summary.
5. **Delivery moves from commit-to-main to draft PRs.** tce commits directly
   and never pushes; a factory needs the Copilot-agent property that workers
   structurally cannot merge their own output. The per-phase commit discipline
   and conventional messages transfer as-is; the branch/PR/merge-gate wrapper
   is new but mechanical.

### Genuinely missing

6. **Intake and dispatch.** tce is human-triggered, one ticket at a time. The
   factory version is a dispatcher that watches the ticket backlog (tmt's
   open-tickets listing is a primitive queue already), spawns headless
   `/tce:work` runs (Claude Code `-p` / Agent SDK / scheduled cloud agents) in
   isolated worktrees or containers, and manages concurrency and merge order.
   This is the biggest new build, but it sits *on top of* tce rather than
   inside it.
7. **Telemetry.** Nothing measures the factory. But the thoughts/ trail is an
   unusually good data substrate: status files record phases, issues
   encountered, verification results, and gate outcomes per ticket. Mining
   them yields cycle time per stage, gate-failure rates, replan frequency,
   manual-verification debt — the factory's DORA equivalent — without
   instrumenting anything new.
8. **The feedback loop.** Production incidents/failing tests re-entering
   intake as tickets; absent, and appropriately so for a plugin — it's an
   integration concern of the surrounding platform.

### The philosophical tension to resolve deliberately

tce's identity is the centaur — the human owns intent and approves the plan. A
factory moves humans to the outer loop and, per DORA/Finster, that's exactly
where rubber-stamping and defect amplification start. tce's advantage is that
its two human gates are already positioned where the literature says the
*irreducible* human decisions live (intent sufficiency, plan trade-offs). So
the honest factory path isn't "remove the gates as trust grows" but "keep the
gates, change their medium, and let the *verification* layer scale instead" —
grow more machine gates, not more machine autonomy past the plan. That's also
the differentiator: most factory products scale generation and hope review
keeps up; a tce-based factory would scale the artifact chain and the gate
family, which is where the field says the moat is.

## Sources

- [BCG Platinion: The Agentic Software Factory](https://www.bcgplatinion.com/insights/the-agentic-software-factory)
- [Mager: Software Factory — The End Goal of Agentic Engineering](https://www.mager.co/blog/2026-03-19-software-factory/)
- [Factory.ai: Factory 2.0 — From coding agents to software factories](https://factory.ai/news/software-factory) and [Code Droid Technical Report](https://factory.ai/news/code-droid-technical-report)
- [GitHub Spec Kit](https://github.github.com/spec-kit/) and [repo](https://github.com/github/spec-kit)
- [martinfowler.com: Understanding SDD — Kiro, spec-kit, and Tessl](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
- [GitHub Blog: Meet the new coding agent](https://github.blog/news-insights/product-news/github-copilot-meet-the-new-coding-agent/) and [Introducing Agent HQ](https://github.blog/news-insights/company-news/welcome-home-agents/)
- [HumanLayer: Advanced Context Engineering for Coding Agents (ACE-FCA)](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md)
- [Anthropic: Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) and [When to use multi-agent systems](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them)
- [DORA: State of AI-assisted Software Development 2025](https://dora.dev/dora-report-2025/)
- [Bryan Finster: AI Broke Your Code Review](https://bryanfinster.substack.com/p/ai-broke-your-code-review-heres-how)
- [Augment Code: Harness engineering](https://www.augmentcode.com/guides/harness-engineering-ai-coding-agents) and [The 80% Problem](https://www.augmentcode.com/guides/the-80-percent-problem-ai-agents-technical-debt)
- [Kessel Run — Wikipedia](https://en.wikipedia.org/wiki/Kessel_Run) and [Rise8 post-mortem](https://www.rise8.us/resources/kessel-run-post-mortem-how-the-usaf-paved-the-way-for-modern-software-development-in-the-dod)
- [GovCIO: Platform One](https://govciomedia.com/platform-one-tackles-next-phase-in-software-delivery/) and [Second Front: defense software agencies](https://www.secondfront.com/resources/blog/the-agencies-ushering-in-the-future-of-defense-software/)
- [Average Geniuses: The End of the Assembly Line](https://www.averagegeniuses.com/the-end-of-the-assembly-line-why-the-dod-software-factory-era-is-over/) and [War on the Rocks: The Air Force is Kneecapping Software Innovation](https://warontherocks.com/2025/10/the-air-force-is-kneecapping-software-innovation/)
- [Red Hat: What is a golden path](https://www.redhat.com/en/topics/platform-engineering/golden-paths) and [platformengineering.org: What are golden paths](https://platformengineering.org/blog/what-are-golden-paths-a-guide-to-streamlining-developer-workflows)
- [Frontiers: Platform engineering and internal developer portals — multivocal literature review](https://www.frontiersin.org/journals/computer-science/articles/10.3389/fcomp.2026.1814498/full)
- [TECHSY: Background coding agents compared](https://techsy.io/en/blog/background-coding-agents-compared)
- [Greptile](https://www.greptile.com/), [Greptile vs CodeRabbit](https://www.greptile.com/greptile-vs-coderabbit), [DevTools Academy: State of AI code review 2025](https://www.devtoolsacademy.com/blog/state-of-ai-code-review-tools-2025)
- [ZenML LLMOps DB: Factory enterprise autonomous software engineering](https://www.zenml.io/llmops-database/enterprise-autonomous-software-engineering-with-ai-droids)
