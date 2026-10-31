# Launchpad

A starter monorepo that takes an idea from design to production on **AWS**,
the **App Store** and **Google Play**, built to be vibe-coded with Claude Code.
Every deployment runs in **GitHub Actions**: you and Claude push code and
trigger workflows; nothing touches AWS from your laptop.

```
web/       React + Vite + TypeScript         -> S3 + CloudFront
mobile/    React Native (Expo)               -> EAS Build -> App Store / Google Play
backend/   Go modular monolith               -> one EC2 instance behind API Gateway
devops/    Terraform + CI deploy scripts     -> any AWS account you choose
.github/   CI, Setup, Deploy, Plan, Destroy, Mobile release workflows
.claude/   Claude Code skills + permissions  -> /kickoff, /design-to-code, /deploy, ...
```

## Start a new idea

```bash
gh repo create my-idea --template MohamedKhorshid/launchpad --private --clone
cd my-idea
make setup          # connects your AWS account via a one-time GitHub workflow
make dev            # backend :8080 + web :5173
claude              # then: /kickoff <describe your idea>
```

Then the loop is:

1. `/kickoff` - Claude writes `docs/product/spec.md` and a slice-by-slice plan
2. Design - make screens in Claude Design / Figma, then `/design-to-code`
3. Build - "build slice 1"; Claude uses `/add-backend-module` for API work
4. Ship - push to `main` and the Deploy workflow updates dev; Claude can run
   `make deploy` / `make plan` itself and read the results
5. Mobile - `/release-mobile` for TestFlight and Google Play
6. Friction with the template? `/template-feedback` logs it in `docs/feedback-log.md`

## What Claude may do

| Allowed | Asks first | Never |
|---------|------------|-------|
| tests, lint, `make plan`, deploy **dev**, read run logs | `git push`, deploy **prod**, mobile builds | Destroy/Setup workflows, secrets, `aws`/`terraform apply` locally |

Enforced in `.claude/settings.json`. For real protection, add a required reviewer
to the `prod` environment in GitHub.

## What you need

| For | Account / tool |
|-----|----------------|
| Everything | GitHub (`gh auth login`), Go 1.24+, Node 22+ |
| Deploys | An AWS account (admin credentials only once, for setup). New accounts: ask AWS Support to enable CloudFront first ([why](docs/getting-started.md#3-connect-an-aws-account-one-time)) |
| Mobile builds | Expo account (free) |
| Store publishing | Apple Developer ($99/yr), Google Play Console ($25 once) |

Details: [docs/getting-started.md](docs/getting-started.md) ·
[architecture](docs/architecture.md) · [mobile release](docs/mobile-release.md)
