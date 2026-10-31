# Template feedback log

Friction found while building real products from this template. Newest first.
Claude appends here via the `template-feedback` skill.

## 2026-10-31 - First dev deploy: OIDC role refused (immutable subject claims)
- **Stage:** setup, deploy
- **What happened:** Setup succeeded, but Deploy failed at `Configure AWS credentials` with `Not authorized to perform sts:AssumeRoleWithWebIdentity`. The repo uses GitHub's immutable OIDC subjects, so the token `sub` is `repo:<owner>@<owner_id>/<repo>@<repo_id>:environment:dev`; the deploy role only trusted `repo:<owner>/<repo>:*`.
- **Workaround:** None (fixed in the template instead).
- **Template fix:** Done. The bootstrap trust policy accepts both subject formats (Setup passes `github.repository_id` / `github.repository_owner_id`). `make setup` on an already-connected repo now offers a repair run that reuses `devops/project.env` and re-applies the role.
- **Severity:** blocker (fixed)

## 2026-10-31 - First CI run failed: terraform fmt + Expo versions
- **Stage:** infra, mobile
- **What happened:** CI failed on `terraform fmt -check` (misaligned `=` in the `module "api"` block of `devops/terraform/app/main.tf`) and on `npx expo install --check` (`react-native-safe-area-context` was `^5.11.0`; SDK 58 wants `~5.10.1`).
- **Workaround:** Realigned the block; pinned the package to `~5.10.1` (read from `node_modules/expo/bundledNativeModules.json` because `expo install` couldn't reach Expo's API from the build sandbox).
- **Template fix:** Done in the template. Lesson: run `terraform fmt` and `npx expo install --check` before the first commit.
- **Severity:** blocker (fixed)

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
