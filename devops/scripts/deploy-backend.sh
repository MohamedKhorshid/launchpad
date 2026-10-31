#!/usr/bin/env bash
# CI-only: called by .github/workflows/deploy.yml.
# Build the Go binary, upload it, and roll it out to the EC2 instance via SSM.
#   devops/scripts/deploy-backend.sh dev
set -euo pipefail

# Deploys run in GitHub Actions (see .github/workflows/deploy.yml).
# Set ALLOW_LOCAL_DEPLOY=1 only for emergencies when Actions is unavailable.
if [ "${CI:-}" != "true" ] && [ "${ALLOW_LOCAL_DEPLOY:-}" != "1" ]; then
  echo "Deploys run in GitHub Actions. Use: make deploy ENV=<env>  (gh workflow run deploy.yml)" >&2
  exit 1
fi

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
"$ROOT/devops/scripts/ssm-run.sh" "$INSTANCE" "/opt/app/deploy.sh $KEY" "deploy $VERSION"

echo "==> Checking $API_URL/health"
for _ in $(seq 1 12); do
  if curl -fsS "$API_URL/health"; then echo; echo "Backend $VERSION is live."; exit 0; fi
  sleep 5
done
echo "Deployed, but the public health check is failing (CloudFront -> Kong -> backend). Check the gateway logs: CloudWatch /<project>-<env>/gateway" >&2
exit 1
