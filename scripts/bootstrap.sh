#!/usr/bin/env bash
# One command from "fresh clone" to "deployed dev environment".
#
#   ./scripts/bootstrap.sh
#
# 1. checks tools      2. names your project     3. connects your AWS account
# 4. creates TF state + GitHub->AWS keyless role  5. (optional) deploys dev
# 6. (optional) creates the GitHub repo and pushes
#
# Safe to re-run: finished steps are skipped.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$ROOT/devops/project.env"
cd "$ROOT"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
die()  { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }
ask()  { # ask "Question" default -> echoes answer
  local q="$1" def="${2:-}" ans
  if [ -n "$def" ]; then read -r -p "  $q [$def]: " ans; else read -r -p "  $q: " ans; fi
  echo "${ans:-$def}"
}
yes()  { local a; read -r -p "  $1 [y/N]: " a; case "$a" in y|Y|yes|YES) return 0;; *) return 1;; esac; }

# ---------------------------------------------------------------- 1. tools
bold "1/6  Checking tools"
missing=0
need() {
  if command -v "$1" >/dev/null 2>&1; then info "ok  $1"; else info "MISSING  $1  ->  $2"; missing=1; fi
}
need git       "https://git-scm.com"
need go        "https://go.dev/dl (1.24+)"
need node      "https://nodejs.org (22+)"
need terraform "https://developer.hashicorp.com/terraform/install (1.10+)"
need aws       "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
need gh        "https://cli.github.com (then: gh auth login)"
need make      "Xcode CLI tools (macOS) or build-essential (Linux)"
[ "$missing" = 0 ] || die "Install the missing tools above, then re-run."

# ---------------------------------------------------------------- 2. naming
bold "2/6  Project settings"
if [ -f "$CONF" ]; then
  # shellcheck disable=SC1090
  source "$CONF"
  info "Already configured (devops/project.env): $PROJECT in $AWS_REGION, repo $GITHUB_REPO"
else
  default_slug="$(basename "$ROOT" | tr '[:upper:]_ ' '[:lower:]--' | tr -cd 'a-z0-9-')"
  PROJECT="$(ask "Project slug (lowercase, used in AWS resource names)" "$default_slug")"
  [[ "$PROJECT" =~ ^[a-z][a-z0-9-]{2,24}$ ]] || die "Slug must be 3-25 chars: lowercase letters, digits, hyphens."
  DISPLAY_NAME="$(ask "App display name" "$(echo "$PROJECT" | perl -pe 's/(^|-)(\w)/ \u$2/g; s/^ //')")"

  gh_user="$(gh api user -q .login 2>/dev/null || echo you)"
  current_repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  GITHUB_REPO="$(ask "GitHub repo (owner/name) that will deploy" "${current_repo:-$gh_user/$PROJECT}")"
  BUNDLE_ID="$(ask "iOS bundle id / Android package" "com.$(echo "$gh_user" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9').$(echo "$PROJECT" | tr -d '-')")"

  AWS_PROFILE_NAME="$(ask "AWS CLI profile to use" "${AWS_PROFILE:-default}")"
  AWS_REGION="$(ask "AWS region" "${AWS_REGION:-us-east-1}")"

  info "Renaming template placeholders..."
  files="$(grep -rIl --exclude-dir={node_modules,.git,dist,bin,.terraform,.expo} \
            -e 'launchpad' -e 'Launchpad' . | grep -v 'scripts/bootstrap.sh' || true)"
  for f in $files; do
    perl -pi -e "s/com\.example\.launchpad/$BUNDLE_ID/g; s/Launchpad/$DISPLAY_NAME/g; s/launchpad/$PROJECT/g" "$f"
  done
  (cd backend && gofmt -w . >/dev/null)
fi

export AWS_PROFILE="${AWS_PROFILE_NAME:-${AWS_PROFILE:-default}}"
export AWS_REGION

# ---------------------------------------------------------------- 3. AWS
bold "3/6  Connecting to AWS (profile: $AWS_PROFILE)"
if ! ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"; then
  die "AWS credentials not working for profile '$AWS_PROFILE'. Run: aws configure sso   (or aws configure)"
fi
info "Account $ACCOUNT_ID, region $AWS_REGION"

# ---------------------------------------------------------------- 4. bootstrap stack
bold "4/6  Creating Terraform state bucket + GitHub deploy role"
if [ -n "${TF_STATE_BUCKET:-}" ] && aws s3api head-bucket --bucket "$TF_STATE_BUCKET" 2>/dev/null; then
  info "Already done (bucket $TF_STATE_BUCKET)"
else
  create_oidc=true
  if aws iam list-open-id-connect-providers --output text | grep -q token.actions.githubusercontent.com; then
    create_oidc=false
    info "GitHub OIDC provider already exists in this account; reusing it."
  fi
  pushd devops/terraform/bootstrap >/dev/null
  terraform init -input=false >/dev/null
  terraform apply -input=false -auto-approve \
    -var="project=$PROJECT" -var="region=$AWS_REGION" \
    -var="github_repo=$GITHUB_REPO" -var="create_oidc_provider=$create_oidc"
  TF_STATE_BUCKET="$(terraform output -raw state_bucket)"
  AWS_ROLE_ARN="$(terraform output -raw deploy_role_arn)"
  # Keep a backup of the bootstrap state next to the app state.
  aws s3 cp terraform.tfstate "s3://$TF_STATE_BUCKET/bootstrap/terraform.tfstate" --only-show-errors
  popd >/dev/null

  cat > "$CONF" <<EOF
# Written by scripts/bootstrap.sh. Committed on purpose: contains no secrets.
# CI sources this file to know where and how to deploy.
PROJECT=$PROJECT
AWS_REGION=$AWS_REGION
AWS_ACCOUNT_ID=$ACCOUNT_ID
TF_STATE_BUCKET=$TF_STATE_BUCKET
AWS_ROLE_ARN=$AWS_ROLE_ARN
GITHUB_REPO=$GITHUB_REPO
EOF
  info "Wrote devops/project.env"
fi

# ---------------------------------------------------------------- 5. deploy dev
bold "5/6  Deploy the dev environment"
info "Creates VPC, EC2 (t4g.small), API Gateway, S3 + CloudFront. Roughly \$15-25/month while running."
info "First run takes ~10 minutes (CloudFront + VPC link are slow to create)."
if yes "Deploy dev now?"; then
  make deploy ENV=dev
else
  info "Skipped. Later: make deploy ENV=dev   (or push to main and let CI do it)"
fi

# ---------------------------------------------------------------- 6. GitHub
bold "6/6  GitHub"
if [ ! -d .git ]; then git init -q -b main; fi
if ! git remote get-url origin >/dev/null 2>&1; then
  if yes "Create private GitHub repo $GITHUB_REPO and push?"; then
    git add -A && git commit -qm "Bootstrap $PROJECT from template" || true
    gh repo create "$GITHUB_REPO" --private --source . --push
  else
    info "Skipped. Later: gh repo create $GITHUB_REPO --private --source . --push"
  fi
else
  info "Remote 'origin' exists. Commit and push devops/project.env to enable CI deploys."
fi

bold "Done."
cat <<EOF

  Next:
    make dev                 run backend (:8080) + web (:5173) locally
    claude                   start Claude Code; try: /kickoff <your idea>
    push to main             CI deploys dev automatically
    Mobile stores            see docs/mobile-release.md (needs Expo + Apple + Google accounts)

EOF
