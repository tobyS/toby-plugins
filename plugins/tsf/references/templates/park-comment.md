<!--
Runtime reference for the tsf software factory. Read at the point of use —
always in full, even if already read earlier in the session — by /tsf:cycle
whenever it parks a ticket and composes the comment itself. Never copied into
consuming projects.

Changes to this file are command-contract changes: every park site in
plugins/tsf/references/cycle-write-phase.md composes its comment from here, and
plugins/tsf/references/templates/result-block.md points at it for the
twice-invalid park, so a change to the shape updates those in the same commit.

This file exists because of TP-0043. Park comments used to be one line of
diagnostic — "parked for a human", then the journal's outcome line verbatim —
written for whoever wrote the dispatcher. The human on the other end is expected
to know none of that: not
what a result block is, not what plan.sh is, and not which of fourteen labels
hands the ticket back. An agent's `blocked` comment has always been required to
say "what is wrong and what would fix it" (result-block.md); a dispatcher's park
comment was not. Now it is.

Contents:
1. Rules for every park comment
2. The park comment (a human must act)
3. The question variant (the factory needs an answer, not an action)
-->

# Rules for every park comment

- **Plain language.** Never name a script, a `result:` value, a journal field, a
  result block, an agent, a step or a mode. The reader is a person who has never
  read tsf's internals, and a park is the worst moment to start.
- **Never name a label except the one you are asking for.** One label, in
  backticks, in the "What to do" list.
- **The diagnostic belongs in the journal.** Link it; do not quote it. The two
  exceptions are the parks where no journal ever reached GitHub — a failed
  `prepare` and a failed push — and there the failing command's last output line
  goes inline, because otherwise it is nowhere.
- **Say what is already done.** A human who cannot tell whether the work is lost
  will go looking for it. Commits that are pushed are safe; say so.
- Plain markdown only: no angle brackets anywhere (they do not survive the
  handoff to the dispatcher), no fenced code blocks — use inline code.
- Links to artifacts are GitHub file links on the ticket branch:
  `https://github.com/[owner/repo]/blob/[branch]/thoughts/factory/GH-[n]/[file]`.

# The park comment

Used by every `tsf:needs-human` park: a failed write, a state mismatch, a
twice-invalid return, a broken environment, a failed `prepare`, a failed push, an
exhausted bound.

````markdown
**tsf · GH-[n] · parked**

[What happened, one or two sentences, in terms the reader already has. Not "the
verify-fix agent returned no valid result block" but "the factory could not
complete this ticket's verification step".]

[What it means for this ticket: what is finished and pushed, what is not, and what
the factory will do when it picks the ticket up again.]

**What to do**
1. [The concrete thing a person must do — or, when nothing needs fixing, say so:
   "Nothing needs fixing here; the ticket only needs handing back."]
2. Set the label `tsf:queued` on this issue to hand it back. The factory resumes
   where it stopped.

Details in the [journal](https://github.com/[owner/repo]/blob/[branch]/thoughts/factory/GH-[n]/journal.md).
````

When no journal reached GitHub, drop the closing line and put the failing
command's last output line in the first paragraph instead.

`tsf:answered` works in place of `tsf:queued` on a park like this, and a person who
has been replying to questions will reach for it. Ask for `tsf:queued`: it is the
one that says "I have acted" without also implying there is something to read.

# The question variant

Used by the format-question park (`cycle-write-phase.md`), where the factory needs
a **reply**, not an action: nothing in the repository is broken except a field in
the factory's own plan document, and the factory will repair it itself once it
knows the shape.

````markdown
**tsf · GH-[n] · needs your answer**

The code for this ticket is built, verified and pushed. What the factory cannot do
is read one field of its own plan document back: [the field, in plain terms — which
increment or addendum, and what is wrong with how it is written].

It has already tried to rewrite that field twice. Rather than keep guessing, it is
asking you.

**What to do**
1. Reply to this comment saying how the field should read. [The shape it must take,
   in one sentence — the same shape the factory was told to use.]
2. Nothing else is needed: the factory restates the field itself and carries on
   from where it stopped.

Only replies by [responder logins, comma-separated] are picked up.

Details in the [journal](https://github.com/[owner/repo]/blob/[branch]/thoughts/factory/GH-[n]/journal.md).
````

Do not ask for a label here — the reply is the signal, and the pickup sets the
label. Do not quote the check's message: translate it.
