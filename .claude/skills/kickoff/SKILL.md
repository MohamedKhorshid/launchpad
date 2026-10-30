---
name: kickoff
description: Turn a new product idea into a spec and build plan for this repo. Use when the user describes an app idea, says "new idea", "kickoff", or there is no docs/product/spec.md yet.
---

# Kickoff: idea -> spec -> plan

Goal: a short, concrete spec that the rest of the workflow (design, backend
modules, screens, deploy) can execute against. Bias toward the smallest version
that proves the idea.

## Steps

1. **Understand.** Ask at most 5 questions, in one message, only about things
   that change what gets built: target user, the one core job, must-have screens,
   whether accounts/sign-in are needed at launch, web vs mobile priority.
   Skip questions the user already answered.
2. **Write `docs/product/spec.md`** with exactly these sections:
   - *Problem & user* (2-3 sentences)
   - *MVP scope* (in / explicitly out)
   - *User stories* (`As a ..., I want ..., so that ...`, max ~8)
   - *Screens* (name, purpose, key elements; note web, mobile or both)
   - *Data model* (entities, fields, relations)
   - *API* (method + path + purpose, grouped by backend module)
   - *Open questions*
3. **Map to modules.** Each backend module = one business capability
   (e.g. `accounts`, `listings`, `orders`). Note which need a database and
   whether sign-in is required; if so, recommend running `add-database` first.
4. **Write `docs/product/plan.md`**: ordered vertical slices, each one
   deployable on its own (module + clients + screens + tests). Slice 1 should
   be demoable within a day.
5. **Hand off.** Tell the user the next step: provide a design (see the
   `design-to-code` skill) or say "build slice 1".

Keep both docs short enough to read in two minutes. Update them as decisions
change; they are the source of truth for later sessions.
