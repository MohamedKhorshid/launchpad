# Architecture

```
                                     ┌──────────────────────────────────┐
 Browser / App ─HTTPS─▶ CloudFront ──┤ /*      ─OAC─▶ S3 (React build)  │
                                     │ /api/*  ─HTTP :8000 + secret hdr ─┐
                                     └──────────────────────────────────┘│
 ┌──────────────────────── VPC ──────────────────────────────────────────▼─────┐
 │ public subnet                                                               │
 │   Kong gateway EC2 t4g.micro (Docker, DB-less, devops/gateway/kong.yml)     │
 │     strips /api, rate limits per client IP, request ids, size limits        │
 │     SG: :8000 from CloudFront origin-facing IPs only; also the NAT          │
 │                         │ :8080                                             │
 │ private subnet          ▼                                                   │
 │   Backend EC2 t4g (Amazon Linux 2023, arm64), no public IP                  │
 │     systemd: /opt/app/server (Go modular monolith)                          │
 │     SG: :8080 from the gateway SG only; no SSH                              │
 │     egress: via gateway NAT; S3 via free VPC gateway endpoint               │
 └─────────────────────────────────────────────────────────────────────────────┘
 Deploys: GitHub Actions ─OIDC─▶ AWS role ─▶ Terraform + S3 artifacts + SSM RunCommand
```

## Why these choices

- **Modular monolith on one EC2**: one binary to build, run, debug and pay for.
  Modules have hard boundaries (no cross-imports of internals), so a module can
  be split into its own service later if it ever needs to scale independently.
- **Public gateway, private backend**: the backend has no public IP and only
  accepts the gateway, so the app is never directly exposed. All edge concerns
  (rate limiting, auth, request ids, size limits) live in one place you control.
- **Kong OSS (DB-less)**: declarative config in git, validated in CI, applied
  live without restarts; a large plugin catalogue (JWT, key-auth, ACLs, ...)
  when you need it. 3.9.x is the last Kong line published as open source.
- **CloudFront in front of Kong**: free managed HTTPS on `*.cloudfront.net`,
  no certificates or DNS to manage, and web + API share one origin (no CORS
  for the web app). Kong only answers CloudFront (IP prefix list + a secret
  `X-Origin-Verify` header that CloudFront adds and Kong requires).
- **Gateway doubles as NAT**: the backend needs outbound access (SSM, third-party
  APIs); a managed NAT gateway would cost ~$35/month. S3 goes through a free
  gateway endpoint, so builds still download if the gateway is down.
- **SSM instead of SSH**: no keys, no open port 22; deploys run `deploy.sh`
  on each instance (backend: health check + auto rollback; gateway: config
  applied through Kong's admin API, rejected configs keep the old one).
- **Terraform state in S3 with native locking** (`use_lockfile`), one state file per environment.

## Scaling path

1. Bigger instance (`instance_type` in `env/<env>.tfvars`).
2. Database off the box (`add-database` skill).
3. ALB + Auto Scaling group with 2+ backend instances; point the Kong `backend` service at the ALB.
4. Managed NAT gateway (and a second gateway instance) when egress must be highly available.
5. Extract a hot module into its own service; add it as another Kong service/route.
