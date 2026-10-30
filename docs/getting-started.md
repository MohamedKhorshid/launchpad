# Getting started

## 1. Install tools

| Tool | macOS (Homebrew) |
|------|------------------|
| Go 1.24+ | `brew install go` |
| Node 22+ | `brew install node@22` |
| Terraform 1.10+ | `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` |
| AWS CLI v2 | `brew install awscli` |
| GitHub CLI | `brew install gh && gh auth login` |
| Claude Code | see https://docs.claude.com |

## 2. Connect an AWS account

Any account works; use a dedicated one per product if you can.

- **IAM Identity Center (recommended):** `aws configure sso`, pick a profile name.
- **Access keys:** `aws configure --profile my-idea` with an admin user's keys.

Check: `aws sts get-caller-identity --profile <profile>`.

Admin rights are only needed on your machine for the one-time `make setup`.
After that, GitHub Actions deploys using a role it assumes via OIDC (no stored keys).

## 3. Run setup

```bash
make setup
```

It asks for a project slug, display name, GitHub repo, bundle id, AWS profile
and region, then:

1. renames the template placeholders,
2. creates the Terraform state bucket and the `<project>-github-deploy` role,
3. writes `devops/project.env` (commit this; it has no secrets),
4. optionally deploys `dev` (~10 minutes the first time),
5. optionally creates the GitHub repo and pushes.

## 4. Develop

```bash
make dev        # Go API on :8080, React on :5173 (proxying /api)
make mobile     # Expo dev server; press i / a for simulators, or scan with Expo Go
```

## 5. Environments

| Env | Deployed by | Notes |
|-----|-------------|-------|
| dev | every push to `main` | t4g.small |
| prod | `gh workflow run deploy.yml -f env=prod` | t4g.medium; add required reviewers to the `prod` environment in GitHub settings |

## Costs (rough, us-east-1, idle)

EC2 t4g.small ~$12, public IPv4 ~$4, Cloud Map private namespace ~$0.50,
CloudFront / API Gateway / S3 cents at low traffic. **About $15-25/month per
environment.** `make destroy ENV=dev` removes everything except the state bucket.

## Tear down completely

```bash
make destroy ENV=prod; make destroy ENV=dev
cd devops/terraform/bootstrap && terraform destroy   # remove prevent_destroy first
```
