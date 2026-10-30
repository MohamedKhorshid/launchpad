#!/usr/bin/env bash
# Build the Go binary, upload it, and roll it out to the EC2 instance via SSM.
#   devops/scripts/deploy-backend.sh dev
set -euo pipefail

ENV="${1:?usage: deploy-backend.sh <env>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TF="$ROOT/devops/scripts/tf.sh"
VERSION="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || date +%s)"

BUCKET="$("$TF" "$ENV" output -raw artifacts_bucket)"
INSTANCE="$("$TF" "$ENV" output -raw instance_id)"
API_URL="$("$TF" "$ENV" output -raw api_url)"

echo "==> Building backend $VERSION (linux/arm64)"
make -C "$ROOT/backend" build-linux VERSION="$VERSION"
BIN="$ROOT/backend/bin/server-linux-arm64"

KEY="backend/builds/$VERSION/server"
echo "==> Uploading to s3://$BUCKET/$KEY"
aws s3 cp "$BIN" "s3://$BUCKET/$KEY" --only-show-errors
aws s3 cp "$BIN" "s3://$BUCKET/backend/latest/server" --only-show-errors

echo "==> Rolling out to $INSTANCE"
CMD_ID="$(aws ssm send-command \
  --instance-ids "$INSTANCE" \
  --document-name AWS-RunShellScript \
  --comment "deploy $VERSION" \
  --parameters "commands=[\"/opt/app/deploy.sh $KEY\"]" \
  --query Command.CommandId --output text)"

# Wait for the command; the instance may still be booting on first deploy.
for _ in $(seq 1 60); do
  STATUS="$(aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$INSTANCE" \
    --query Status --output text 2>/dev/null || echo Pending)"
  case "$STATUS" in
    Success) break ;;
    Failed|Cancelled|TimedOut)
      aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$INSTANCE" \
        --query '[StandardOutputContent,StandardErrorContent]' --output text
      echo "Deploy failed ($STATUS)" >&2; exit 1 ;;
  esac
  sleep 5
done
[ "${STATUS:-}" = "Success" ] || { echo "Timed out waiting for deploy" >&2; exit 1; }

echo "==> Checking $API_URL/health"
for _ in $(seq 1 12); do
  if curl -fsS "$API_URL/health"; then echo; echo "Backend $VERSION is live."; exit 0; fi
  sleep 5
done
echo "Deployed, but the public health check is failing. Check API Gateway logs." >&2
exit 1
