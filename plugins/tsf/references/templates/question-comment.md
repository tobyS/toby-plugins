<!--
Runtime reference for the tsf software factory. Read at the point of use —
always in full, even if already read earlier in the session — by the tsf:triage,
tsf:research and tsf:plan agents before they compose the `tsf-comment` block of
their result. Never copied into consuming projects.

Changes to this file are command-contract changes: the comment is posted
verbatim by /tsf:cycle, and the plan summary's closing line is the approval
instruction tsf:plan classifies replies against, so changing it requires
updating plugins/tsf/agents/plan.md in the same commit.

Contents:
1. Rules for every comment
2. The question comment (triage, research)
3. The plan summary (plan gate)
4. The outcome comment (a step that continues)
5. The resume confirmation line
-->

# Rules for every comment

- One comment per step. Decisions and outcomes, never step lists, never a
  transcript.
- Plain markdown only: no angle brackets anywhere (they do not survive the
  handoff to the dispatcher), no fenced code blocks — use inline code.
- Links to artifacts are GitHub file links on the ticket branch:
  `https://github.com/[owner/repo]/blob/[branch]/thoughts/factory/GH-[n]/[file]`.
- Questions are batched: everything the step needs, numbered, in one comment,
  each **in full** and self-contained — never "see research.md".

# The question comment

Used by triage and research when they park the ticket with questions.

````markdown
**tsf · GH-[n] · [triage | research] needs your answers**

[Informed understanding: two to four sentences on what the factory understands
this ticket to ask for.]

**Key findings**
- [What the step established that the questions rest on — one line each]

**Questions**
1. [Question in full, with the options where there are real ones]
2. [...]

Reply to this comment with your answers, numbered like the questions (for example `1. yes, both`). Only replies by [responder logins, comma-separated] are picked up.
````

# The plan summary

Used by the plan step every time it parks at the plan gate. Its job is to let
the human approve intent and trade-offs in under a minute. **Never the increment
list.**

````markdown
**tsf · GH-[n] · plan ready for approval**

[Informed understanding: two to four sentences on what will be built and why.]

**Key findings**
- [The research facts the plan rests on — one line each]

**Decisions**
- **[Decision]** — rejected: [the alternative, one line]

**Irregular**
- [Anything unusual: a risk, a departure from the project's conventions, a
  verification that can only be done manually. Omit this section when there is
  nothing.]

**Questions**
1. [Question in full. Omit this section when there are none.]

Full plan: [plan.md](https://github.com/[owner/repo]/blob/[branch]/thoughts/factory/GH-[n]/plan.md) · research: [research.md](https://github.com/[owner/repo]/blob/[branch]/thoughts/factory/GH-[n]/research.md)

Reply `approved` to approve the plan; anything else is treated as feedback and the plan is revised. Only replies by [responder logins, comma-separated] are picked up.
````

When the summary follows a revision, add one line after the heading:
`Revised after your feedback: [what changed, one sentence].`

# The outcome comment

Used when a step continues without parking. Two sentences at most, plus the
artifact link.

````markdown
**tsf · GH-[n] · [step] done**

[What the step produced or decided, and what happens next.] [[file](link)]
````

Plan approval uses: `**tsf · GH-[n] · plan approved**` and "Implementation is
next."

# The resume confirmation line

When a step resumes with a responder's reply and folds it into an artifact, the
comment's **first line** is the confirmation, followed by a blank line and the
comment as above:

````markdown
Folded your answers into [spec.md | plan.md] (commit `[short sha]`).
````

Plan approval without a change folds nothing and has no confirmation line.
