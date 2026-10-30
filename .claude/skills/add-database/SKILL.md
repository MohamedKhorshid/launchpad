---
name: add-database
description: Add persistent storage (PostgreSQL on RDS or DynamoDB) to the Go backend and Terraform. Use when data must survive restarts, the user asks for a database, or a module still uses MemoryStore before launch.
---

# Add a database

Ask the user which option fits (one question), recommending based on the spec:

| Option | Pick when | Monthly cost (approx.) |
|--------|-----------|------------------------|
| **PostgreSQL on RDS** (`db.t4g.micro`) | Relational data, joins, reporting; default for most apps | ~$15 |
| **DynamoDB** (on-demand) | Simple key-value access patterns, spiky traffic, near-zero idle cost | ~$0 idle |
| **SQLite on the EC2 disk** | Throwaway prototype only; data tied to one instance | $0 |

## PostgreSQL steps

1. Terraform: new module `devops/terraform/modules/database` with
   `aws_db_subnet_group` (needs 2 subnets; add private subnets to `network`),
   security group allowing 5432 **only** from the backend instance SG,
   `aws_db_instance` (postgres, `manage_master_user_password = true`,
   `storage_encrypted = true`, `deletion_protection` true in prod).
2. Give the instance role `secretsmanager:GetSecretValue` on the master secret.
   Pass host/db name/secret ARN to the instance via `/etc/app/env` (user data).
3. Backend: `internal/platform/db` opens a `pgxpool` (github.com/jackc/pgx/v5),
   reading the password from Secrets Manager at startup.
4. Migrations: `backend/migrations/NNN_name.sql`, applied at startup with
   `github.com/pressly/goose/v3` (embed with `embed.FS`).
5. Each module gets a `PostgresStore` implementing its `Store` interface;
   keep `MemoryStore` for unit tests.

## DynamoDB steps

1. Terraform: `aws_dynamodb_table` per module (or single-table), `PAY_PER_REQUEST`,
   point-in-time recovery on; grant the instance role access to those tables only.
2. Backend: aws-sdk-go-v2 `dynamodb` client in `internal/platform/aws`; table
   names via env vars from user data.
3. Each module gets a `DynamoStore` implementing its `Store` interface.

## Finish

`make lint && make test`, `make plan ENV=dev`, show the plan summary, and ask
before deploying. Note: changing user data does not replace the running
instance; tell the user to run `devops/scripts/tf.sh dev apply -replace=module.backend.aws_instance.app`
or update `/etc/app/env` via SSM.
