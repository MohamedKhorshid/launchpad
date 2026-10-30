# Launchpad

A starter monorepo that takes an idea from design to production on **AWS**,
the **App Store** and **Google Play**, built to be vibe-coded with Claude Code.

```
web/       React + Vite + TypeScript         -> S3 + CloudFront
mobile/    React Native (Expo)               -> EAS Build -> App Store / Google Play
backend/   Go modular monolith               -> one EC2 instance behind API Gateway
devops/    Terraform + deploy scripts        -> any AWS account you choose
.claude/   Claude Code skills + permissions  -> /kickoff, /design-to-code, /deploy, ...
```

## Start a new idea

```bash
gh repo create my-idea --template <you>/launchpad --private --clone
cd my-idea
make setup          # names the project, connects your AWS account, optional first deploy
make dev            # backend :8080 + web :5173
claude              # then: /kickoff <describe your idea>
```

Then the loop is:

1. `/kickoff` - Claude writes `docs/product/spec.md` and a slice-by-slice plan
2. Design - make screens in Claude Design / Figma, then `/design-to-code`
3. Build - "build slice 1"; Claude uses `/add-backend-module` for API work
4. Ship - push to `main` and CI deploys dev; `/deploy` for prod
5. Mobile - `/release-mobile` for TestFlight and Google Play
6. Friction with the template? `/template-feedback` logs it in `docs/feedback-log.md`

## What you need

| For | Account / tool |
|-----|----------------|
| Everything | GitHub (`gh auth login`), Go 1.24+, Node 22+, Terraform 1.10+, AWS CLI v2 |
| Deploys | An AWS account with admin access for the one-time setup |
| Mobile builds | Expo account (free) |
| Store publishing | Apple Developer ($99/yr), Google Play Console ($25 once) |

Details: [docs/getting-started.md](docs/getting-started.md) ·
[architecture](docs/architecture.md) · [mobile release](docs/mobile-release.md)

## Commands

Run `make help`. The main ones: `make dev`, `make test`, `make lint`,
`make plan ENV=dev`, `make deploy ENV=dev`, `make mobile`.
