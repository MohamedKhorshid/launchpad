# Architecture

```
                 ┌──────────────┐        ┌──────────────────────────┐
 Browser ───────▶│  CloudFront  │──OAC──▶│ S3 (React build)         │
                 └──────────────┘        └──────────────────────────┘
 Browser / App ─▶ API Gateway (HTTP API, throttling, CORS, access logs)
                      │ VPC link
                      ▼
                 Cloud Map service (SRV: private IP + port 8080)
                      │
            ┌─────────▼─────────── VPC (2 public subnets, no NAT) ┐
            │  EC2 t4g (Amazon Linux 2023, arm64)                  │
            │   systemd: /opt/app/server  (Go modular monolith)    │
            │   SG: :8080 only from the VPC link SG; no SSH        │
            └──────────────────────────────────────────────────────┘
 Deploys: GitHub Actions ─OIDC─▶ AWS role ─▶ Terraform + S3 artifacts + SSM RunCommand
```

## Why these choices

- **Modular monolith on one EC2**: one binary to build, run, debug and pay for.
  Modules have hard boundaries (no cross-imports of internals), so a module can
  be split into its own service later if it ever needs to scale independently.
- **API Gateway in front**: public HTTPS endpoint, throttling, CORS, access
  logs and (later) JWT auth without exposing the instance.
- **VPC link + Cloud Map instead of a load balancer**: saves ~$18/month per
  env. Swap in an ALB when you run more than one instance.
- **No NAT gateway**: the instance has a public IP for outbound traffic but no
  inbound rules except from the VPC link. Saves ~$35/month.
- **SSM instead of SSH**: no keys, no open port 22; deploys run `deploy.sh`,
  which health-checks and rolls back automatically.
- **Terraform state in S3 with native locking** (`use_lockfile`), one state file per environment.

## Scaling path

1. Bigger instance (`instance_type` in `env/<env>.tfvars`).
2. Database off the box (`add-database` skill).
3. ALB + Auto Scaling group with 2+ instances; point the API integration at the ALB listener.
4. Extract a hot module into its own service.
