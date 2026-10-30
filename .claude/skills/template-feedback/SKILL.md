---
name: template-feedback
description: Record friction, bugs or ideas about this starter template (setup, deploy, structure, skills) in docs/feedback-log.md. Use when something in the template was confusing, broken, slow, or had to be worked around, or when the user says "log feedback" / "retro".
---

# Template feedback

This repo was generated from a starter template that is improved from real use.
Capture what happened so the template can be fixed upstream.

1. Append an entry to `docs/feedback-log.md` (create from the header if missing):

   ```
   ## <YYYY-MM-DD> - <short title>
   - **Stage:** setup | design | backend | web | mobile | infra | deploy | stores | claude-skills
   - **What happened:** <facts, including exact error text>
   - **Workaround:** <what fixed it, if anything>
   - **Template fix:** <concrete change to the template: file + what to change>
   - **Severity:** blocker | annoying | idea
   ```
2. If the fix is small and safe, offer to apply it in this repo too.
3. At the end of a session with several entries, summarize the top fixes in
   3 bullets so the user can paste them into the template repo.
