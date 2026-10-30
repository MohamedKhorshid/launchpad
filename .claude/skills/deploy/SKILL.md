---
name: deploy
description: Ship the current code to AWS (dev or prod) and verify it works. Use when the user says deploy, ship, release to AWS, push it live, or asks why a deploy failed.
---

# Deploy

## Preflight

1. `devops/project.env` must exist. If not, tell the user to run `make setup`.
2. `make lint && make test` must pass. Fix failures before deploying.
3. `make plan ENV=<env>`; summarize what changes (adds/changes/destroys). If
   anything is **destroyed or replaced** (especially `aws_instance`), call it out
   and get explicit confirmation.

## Preferred path: CI

If the repo has a GitHub remote, the normal deploy is: commit, push to `main`
(dev deploys automatically), watch with `gh run watch`. For prod:
`gh workflow run deploy.yml -f env=prod` - only when the user explicitly asks.

## Local path

`make deploy ENV=dev` (infra, then backend, then web). Never prod locally unless
the user explicitly asks in this conversation.

## Verify

- `curl -fsS $(devops/scripts/tf.sh dev output -raw api_url)/health` returns the new version (git sha).
- Open the web URL (`tf.sh dev output -raw web_url`).

## When it fails

| Symptom | Likely cause / fix |
|---------|--------------------|
| SSM command never runs | Instance still booting, or SSM agent not registered: wait 2-3 min, check `aws ssm describe-instance-information` |
| `deploy.sh` health check fails | App crashes on start: `aws ssm send-command ... journalctl -u app -n 100`; it auto-rolls back |
| API returns 503 | Cloud Map registration / VPC link not ready (first deploy takes ~5 min), or app down |
| CORS errors in browser | Origin missing from `extra_cors_origins` / CloudFront domain; re-apply |
| Terraform state lock | Another run in progress; wait, or `terraform force-unlock` only if certain |
