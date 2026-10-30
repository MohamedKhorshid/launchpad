# Template feedback log

Friction found while building real products from this template. Newest first.
Claude appends here via the `template-feedback` skill.

## 2026-10-31 - Deploys moved to GitHub Actions: check on first run
- **Stage:** setup, deploy
- **What happened:** Local deploy scripts were replaced by workflows (Setup, Deploy, Plan, Destroy). None have run against a real account yet.
- **Template fix:** Confirm (1) `make setup` hands credentials over via `aws configure export-credentials` and deletes them afterwards, (2) the Setup workflow commits `devops/project.env` and dispatches Deploy, (3) `scripts/run-workflow.sh` finds the right run id and prints `DEPLOY_RESULT`, (4) Plan posts a PR comment.
- **Severity:** blocker until confirmed

## 2026-10-31 - Initial template: unverified items to check on first real run
- **Stage:** infra, claude-skills
- **What happened:** Template was written in an environment without Terraform or AWS access, so `terraform validate` and a real deploy have not run yet. CI validates on first push.
- **Template fix:** Confirm (1) CI `terraform` job passes, (2) first `make deploy ENV=dev` reaches `/health` through API Gateway, (3) the `expo@claude-plugins-official` and `frontend-design@claude-plugins-official` plugins in `.claude/settings.json` resolve, (4) `npx expo install --check` passes (react-native-safe-area-context was added with npm).
- **Severity:** blocker until confirmed
