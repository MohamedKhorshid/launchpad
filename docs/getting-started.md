# Getting started

Everything that touches AWS runs in **GitHub Actions**. Your machine (and
Claude) only write code, push, and trigger workflows.

## 1. Install tools

| Tool | Needed for | macOS (Homebrew) |
|------|------------|------------------|
| GitHub CLI | setup, deploys | `brew install gh && gh auth login` |
| Go 1.24+ | local backend | `brew install go` |
| Node 22+ | local web/mobile | `brew install node@22` |
| AWS CLI v2 | optional: hand over credentials during setup | `brew install awscli` |
| Claude Code | vibe coding | see https://docs.claude.com |

No Terraform needed locally.

## 2. Create a repo from the template

```bash
gh repo create my-idea --template MohamedKhorshid/launchpad --private --clone
cd my-idea
```

## 3. Connect an AWS account (one time)

> **Brand-new AWS account?** AWS blocks CloudFront (used for the web app) on
> many new accounts until they are verified, and the first deploy then fails
> with `Your account must be verified before you can add new CloudFront
> resources`. Before you start, open a free case in the
> [AWS Support Center](https://console.aws.amazon.com/support/home#/case/create)
> (Account and billing → "Request CloudFront access / account verification").
> It usually takes from a few hours to a day.

```bash
make setup
```

It asks for a project slug, display name, bundle id and region, then:

1. stores AWS credentials as **temporary repo secrets**. With the AWS CLI it
   exports them from a local profile without printing them; prefer an IAM
   Identity Center (SSO) profile so they expire on their own. Otherwise you paste
   an admin access key.
2. runs the **Setup** workflow, which renames the template, creates the Terraform
   state bucket and a GitHub OIDC deploy role, and commits `devops/project.env`;
3. **deletes the secrets**. From now on GitHub deploys keylessly via OIDC;
4. starts the first **dev** deploy (~10 minutes).

Prefer clicking? Add `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (and
`AWS_SESSION_TOKEN`) in repo Settings → Secrets → Actions, run **Setup (one-time)**
from the Actions tab, then delete the secrets.

Deploys fail at **Configure AWS credentials**? Run `make setup` again and answer
`y` to repair: it reuses your project and region, re-applies the deploy role,
and starts a fresh dev deploy. Your AWS resources stay as they are.

## 4. Protect prod

Repo Settings → Environments → `prod` → add yourself as a **required reviewer**.
Every prod deploy then waits for your click, whoever triggered it.

## 5. Develop and ship

```bash
make dev                         # Go API :8080 + React :5173, no AWS involved
git push                         # main -> Deploy workflow -> dev
make deploy ENV=dev COMPONENT=web   # redeploy one part (triggers the workflow and waits)
make plan ENV=dev                # Terraform plan, nothing applied
make deploy ENV=prod             # from main, after reviewer approval
make status                      # recent runs
```

## Workflows

| Workflow | Started by | What it does |
|----------|------------|--------------|
| CI | every push / PR | Go, web, mobile checks; `terraform validate` |
| Setup (one-time) | `make setup` | connects the repo to AWS |
| Deploy | push to `main` (dev) or `make deploy` | Terraform apply + backend + web |
| Plan | PRs touching `devops/`, or `make plan` | Terraform plan, posted on the PR |
| Destroy | you, from the Actions tab | tears down an env (type the env name to confirm) |
| Mobile release | `make mobile-build` | EAS build, optional store submit |

## Costs (rough, us-east-1, idle)

EC2 t4g.small ~$12, public IPv4 ~$4, Cloud Map private namespace ~$0.50,
CloudFront / API Gateway / S3 cents at low traffic. **About $15-25/month per
environment.** Run the **Destroy** workflow to remove an environment.

## Tear down completely

1. Run **Destroy** for `prod` and `dev` from the Actions tab.
2. In the AWS console, delete the `<project>-github-deploy` IAM role and empty +
   delete the `<project>-tfstate-<account>` bucket.
