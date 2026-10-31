---
name: deploy
description: Ship code to AWS (dev or prod) through GitHub Actions and verify it works; also run Terraform plans and diagnose failed deploys. Use when the user says deploy, ship, release, push it live, plan infra, or asks why a deploy failed.
---

# Deploy (via GitHub Actions only)

All AWS changes happen in GitHub Actions. You trigger workflows with
`scripts/run-workflow.sh` (or `make`), which starts the run, waits, and prints
`RUN_RESULT <conclusion> <url>` plus the failed-step logs if it fails.
Never run `devops/scripts/*`, `terraform apply`, or `aws` commands locally.

## Preflight

1. `devops/project.env` must exist. If not, the repo isn't connected to AWS:
   ask the user to run `make setup` themselves (it needs their AWS credentials).
2. `make lint && make test` pass.
3. Commit and **push** (ask before pushing). Workflows build what is on GitHub,
   not the local tree; `run-workflow.sh` warns if they differ.

## Commands

| Goal | Command |
|------|---------|
| Preview infra changes | `make plan ENV=dev` |
| Deploy everything to dev | `make deploy ENV=dev` (also happens automatically on push to `main`) |
| Deploy one part | `make deploy ENV=dev COMPONENT=backend` (`infra`, `backend`, `web`) |
| Recreate the EC2 instance (user data changed) | `scripts/run-workflow.sh deploy.yml -f env=dev -f component=infra -f replace_backend_instance=true` |
| Deploy to prod | `make deploy ENV=prod`: only when the user explicitly asks; runs from `main`; may wait for a reviewer in the GitHub `prod` environment |
| Check runs / logs | `make status`, `gh run view <id> --log-failed` |

After a push to `main`, follow the automatic dev deploy:
`gh run watch $(gh run list --workflow deploy.yml --limit 1 --json databaseId -q '.[0].databaseId') --exit-status`

Before a deploy that includes `infra`, run `make plan ENV=<env>` and summarize
the `PLAN_RESULT` line. If anything is **destroyed or replaced** (the plan log
warns about it), stop and get explicit confirmation.

## Verify

The run prints `DEPLOY_RESULT env=... web=<url> api=<url> sha=<sha>`.
Check `curl -fsS <api>/health` reports that sha as `version`, and give the user the web URL.

## When it fails

Read the failed step's log (printed by `run-workflow.sh`), then:

| Failed step / symptom | Likely cause / fix |
|-----------------------|--------------------|
| `preflight` skipped everything | Repo not set up: user runs `make setup` |
| Configure AWS credentials (`Not authorized to perform sts:AssumeRoleWithWebIdentity`) | Role trust doesn't match this repo's OIDC subject (repo renamed/transferred, or created before the immutable-subject fix): ask the user to run `make setup` and answer `y` to repair |
| Infrastructure | Read the Terraform error; fix HCL, push, redeploy. State lock: another run is active; wait |
| Backend: SSM never runs | First boot still in progress or SSM agent not registered; re-run `COMPONENT=backend` after 3 min |
| Backend: health check failed | App crashes on start; `deploy.sh` already rolled back. Reproduce with `make dev`, fix, redeploy |
| Infrastructure: `Your account must be verified before you can add new CloudFront resources` | AWS account restriction, not a code bug. The user must open an AWS Support case (Account and billing) asking to verify the account / enable CloudFront. Don't change Terraform. Once AWS confirms, `make deploy ENV=dev`: Terraform resumes from what was already created |
| API returns 503 | VPC link / Cloud Map not ready (first deploy ~5 min) or app down |
| CORS errors | Origin missing from `extra_cors_origins`; edit tfvars, deploy `infra` |
| Stuck waiting | `prod` environment needs reviewer approval in GitHub |

Re-run a failed run as-is with `gh run rerun <id> --failed` (ask first).
