# Template feedback log

Friction found while building real products from this template. Newest first.
Claude appends here via the `template-feedback` skill.

## 2026-10-31 - Initial template: unverified items to check on first real run
- **Stage:** infra, claude-skills
- **What happened:** Template was written in an environment without Terraform or AWS access, so `terraform validate` and a real deploy have not run yet. CI validates on first push.
- **Template fix:** Confirm (1) CI `terraform` job passes, (2) first `make deploy ENV=dev` reaches `/health` through API Gateway, (3) the `expo@claude-plugins-official` and `frontend-design@claude-plugins-official` plugins in `.claude/settings.json` resolve, (4) `npx expo install --check` passes (react-native-safe-area-context was added with npm).
- **Severity:** blocker until confirmed
