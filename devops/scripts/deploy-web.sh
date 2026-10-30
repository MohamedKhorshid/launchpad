#!/usr/bin/env bash
# Build the React app against this environment's API and publish it to CloudFront.
#   devops/scripts/deploy-web.sh dev
set -euo pipefail

ENV="${1:?usage: deploy-web.sh <env>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TF="$ROOT/devops/scripts/tf.sh"

BUCKET="$("$TF" "$ENV" output -raw web_bucket)"
DIST="$("$TF" "$ENV" output -raw web_distribution_id)"
API_URL="$("$TF" "$ENV" output -raw api_url)"
WEB_URL="$("$TF" "$ENV" output -raw web_url)"

echo "==> Building web (API: $API_URL)"
cd "$ROOT/web"
npm ci --no-audit --no-fund
VITE_API_URL="$API_URL" npm run build

echo "==> Uploading to s3://$BUCKET"
# Hashed assets: cache forever. index.html: always revalidate.
aws s3 sync dist "s3://$BUCKET" --delete --only-show-errors \
  --exclude index.html --cache-control "public,max-age=31536000,immutable"
aws s3 cp dist/index.html "s3://$BUCKET/index.html" --only-show-errors \
  --cache-control "no-cache"

aws cloudfront create-invalidation --distribution-id "$DIST" --paths "/index.html" >/dev/null
echo "Web is live at $WEB_URL"
