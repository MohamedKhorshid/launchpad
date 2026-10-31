#!/usr/bin/env bash
# CI-only: called by .github/workflows/deploy.yml.
# Render devops/gateway/kong.yml for this environment, validate it with Kong,
# and apply it live on the gateway instance via SSM (no restart).
#   devops/scripts/deploy-gateway.sh dev
set -euo pipefail

# Deploys run in GitHub Actions (see .github/workflows/deploy.yml).
# Set ALLOW_LOCAL_DEPLOY=1 only for emergencies when Actions is unavailable.
if [ "${CI:-}" != "true" ] && [ "${ALLOW_LOCAL_DEPLOY:-}" != "1" ]; then
  echo "Deploys run in GitHub Actions. Use: make deploy ENV=<env>  (gh workflow run deploy.yml)" >&2
  exit 1
fi

ENV="${1:?usage: deploy-gateway.sh <env>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TF="$ROOT/devops/scripts/tf.sh"
VERSION="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || date +%s)"

BUCKET="$("$TF" "$ENV" output -raw artifacts_bucket)"
INSTANCE="$("$TF" "$ENV" output -raw gateway_instance_id)"
IMAGE="$("$TF" "$ENV" output -raw gateway_image)"
export BACKEND_URL ORIGIN_SECRET RATE_LIMIT_PER_SECOND RATE_LIMIT_PER_MINUTE
BACKEND_URL="$("$TF" "$ENV" output -raw backend_url)"
ORIGIN_SECRET="$("$TF" "$ENV" output -raw gateway_origin_secret)"
[ "${GITHUB_ACTIONS:-}" = "true" ] && echo "::add-mask::$ORIGIN_SECRET"
RATE_LIMIT_PER_SECOND="$("$TF" "$ENV" output -raw api_rate_limit_per_second)"
RATE_LIMIT_PER_MINUTE="$("$TF" "$ENV" output -raw api_rate_limit_per_minute)"

OUT="$(mktemp -d)/kong.yml"
envsubst '$BACKEND_URL $ORIGIN_SECRET $RATE_LIMIT_PER_SECOND $RATE_LIMIT_PER_MINUTE' \
  < "$ROOT/devops/gateway/kong.yml" > "$OUT"

echo "==> Validating gateway config with $IMAGE"
docker run --rm -e KONG_DATABASE=off -v "$OUT:/kong.yml:ro" "$IMAGE" kong config parse /kong.yml

KEY="gateway/builds/$VERSION/kong.yml"
echo "==> Uploading to s3://$BUCKET/$KEY"
aws s3 cp "$OUT" "s3://$BUCKET/$KEY" --only-show-errors
aws s3 cp "$OUT" "s3://$BUCKET/gateway/latest/kong.yml" --only-show-errors
rm -f "$OUT"

echo "==> Applying on $INSTANCE"
"$ROOT/devops/scripts/ssm-run.sh" "$INSTANCE" "/opt/gateway/deploy.sh $KEY" "gateway $VERSION"
echo "Gateway config $VERSION is live."

# The gateway is also the private subnet's NAT, which only works with the
# source/dest check off. Catch drift here instead of as a backend without internet.
CHECK="$(aws ec2 describe-instance-attribute --instance-id "$INSTANCE" --attribute sourceDestCheck \
  --query SourceDestCheck.Value --output text)"
if [ "$CHECK" != "False" ]; then
  echo "Gateway source/dest check is enabled, so NAT for the private subnet is broken." >&2
  echo "Fix: make deploy ENV=$ENV COMPONENT=infra (Terraform sets it back to false)." >&2
  exit 1
fi
echo "NAT forwarding enabled on the gateway."
