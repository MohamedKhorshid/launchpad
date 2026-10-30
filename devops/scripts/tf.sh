#!/usr/bin/env bash
# Run Terraform for one environment with the right remote state.
# Used by the GitHub Actions workflows. Locally (with AWS credentials) only
# read-only commands are allowed: plan, output, state list, ...
#   devops/scripts/tf.sh dev plan
#   devops/scripts/tf.sh dev output -raw api_url
set -euo pipefail

ENV="${1:?usage: tf.sh <env> <terraform args...>}"; shift
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$ROOT/devops/terraform/app"
CONF="$ROOT/devops/project.env"

[ -f "$CONF" ] || { echo "Missing devops/project.env. Run scripts/bootstrap.sh first." >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONF"   # PROJECT, AWS_REGION, TF_STATE_BUCKET
: "${TF_STATE_BUCKET:?}" "${AWS_REGION:?}" "${PROJECT:?}"

cd "$APP_DIR"

# Re-init when switching environments (each env has its own state key).
if [ "$(cat .terraform/.env 2>/dev/null || true)" != "$ENV" ]; then
  terraform init -input=false -reconfigure \
    -backend-config="bucket=$TF_STATE_BUCKET" \
    -backend-config="key=app/$ENV.tfstate" \
    -backend-config="region=$AWS_REGION" >&2
  echo "$ENV" > .terraform/.env
fi

CMD="${1:-plan}"; shift || true

# Changes to AWS only happen in GitHub Actions (deploy.yml / destroy.yml).
case "$CMD" in
  apply|destroy|import)
    if [ "${CI:-}" != "true" ] && [ "${ALLOW_LOCAL_DEPLOY:-}" != "1" ]; then
      echo "terraform $CMD runs in GitHub Actions. Use: make deploy ENV=$ENV / the Destroy workflow." >&2
      exit 1
    fi ;;
esac
case "$CMD" in
  plan|apply|destroy|import|refresh)
    terraform "$CMD" -input=false -var-file="env/$ENV.tfvars" \
      -var="project=$PROJECT" -var="region=$AWS_REGION" "$@" ;;
  *)
    terraform "$CMD" "$@" ;;
esac
