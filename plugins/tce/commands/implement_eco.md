---
description: Run /tce:implement on a Sonnet-class model to cut cost/quota use — same workflow, opt-in. Cost-tuned variant of step 4 in the tce workflow.
argument-hint: "[ticket-id | plan path]"
model: sonnet
disable-model-invocation: true
---

# Implement (Eco)

Runs `/tce:implement` on a Sonnet-class model instead of your session's active model
— the "big model plans, Sonnet implements" cost pattern (see the tce README's "Cost
tuning" section for when to reach for this over plain `/tce:implement`). The session
reverts to your model on your next prompt. This command has no workflow content of
its own.

**CRITICAL: You MUST run the full `/tce:implement` process.**

Invoke the `tce:implement` skill (via the Skill tool) with `$ARGUMENTS` as args.
