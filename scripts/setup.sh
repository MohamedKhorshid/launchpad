#!/usr/bin/env bash
# One-time: connect this repo to an AWS account, entirely through GitHub Actions.
#   make setup
#
# Needs only git + gh locally (aws CLI optional, to hand over credentials).
# 1. pushes the repo if needed   2. stores short-lived AWS credentials as repo secrets
# 3. runs the "Setup (one-time)" workflow   4. deletes the secrets   5. follows the first deploy
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
RUN="$ROOT/scripts/run-workflow.sh"

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ask()  { local a; read -r -p "  $1 [$2]: " a; echo "${a:-$2}"; }
die()  { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

command -v gh  >/dev/null || die "Install the GitHub CLI: https://cli.github.com"
command -v git >/dev/null || die "Install git"
gh auth status >/dev/null 2>&1 || die "Run: gh auth login"

git pull -q --rebase 2>/dev/null || true   # pick up project.env if setup ran elsewhere

REPAIR=false
if [ -f devops/project.env ]; then
  echo "This repo is already connected to AWS (devops/project.env exists)."
  echo "Re-running setup repairs the connection (e.g. deploys fail at 'Configure AWS"
  echo "credentials') and keeps the same project, region and AWS resources."
  case "$(ask "Repair the AWS connection? (y/N)" "N")" in
    y|Y|yes) REPAIR=true ;;
    *) echo "  Nothing to do. To redeploy: make deploy ENV=dev"; exit 0 ;;
  esac
fi

bold "1/4  GitHub repo"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
[ -n "$REPO" ] || die "This folder isn't linked to a GitHub repo. Create one from the template:
  gh repo create <name> --template MohamedKhorshid/launchpad --private --clone"
git push -q origin HEAD 2>/dev/null || true
echo "  $REPO"

bold "2/4  Project identity"
if $REPAIR; then
  # shellcheck disable=SC1091
  PROJECT="$(. devops/project.env && echo "$PROJECT")"
  REGION="$(. devops/project.env && echo "$AWS_REGION")"
  DISPLAY="$PROJECT"   # unused on repair: the template was already renamed
  BUNDLE="$(perl -ne 'print $1 and exit if /"bundleIdentifier":\s*"([^"]+)"/' mobile/app.json)"
  echo "  $PROJECT in $REGION (from devops/project.env)"
else
  OWNER="$(echo "${REPO%%/*}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
  NAME_DEFAULT="$(echo "${REPO##*/}" | tr '[:upper:]_ ' '[:lower:]--' | tr -cd 'a-z0-9-')"
  PROJECT="$(ask "Project slug (AWS resource names)" "$NAME_DEFAULT")"
  DISPLAY="$(ask "App display name" "$(echo "$PROJECT" | perl -pe 's/(^|-)(\w)/ \u$2/g; s/^ //')")"
  BUNDLE="$(ask "iOS bundle id / Android package" "com.$OWNER.$(echo "$PROJECT" | tr -d '-')")"
  REGION="$(ask "AWS region" "${AWS_REGION:-us-east-1}")"
fi

bold "3/4  AWS credentials (one-time, deleted right after setup)"
put_secret() { printf '%s' "$2" | gh secret set "$1" --repo "$REPO" >/dev/null; }
secret_prompt() { # secret_prompt "Label" -> echoes hidden input
  local v; read -r -s -p "  $1: " v; echo >&2; echo "$v"
}

METHOD="paste"
if command -v aws >/dev/null; then
  echo "  The AWS CLI is installed. You can hand over a local profile (nothing to copy)."
  PROFILE="$(ask "AWS CLI profile name, or 'paste' to enter keys by hand" "${AWS_PROFILE:-default}")"
  [ "$PROFILE" = "paste" ] || METHOD="profile"
else
  echo "  AWS CLI not found, so keys will be entered by hand."
  echo "  (Prefer profiles? Ctrl-C, run 'brew install awscli && aws configure sso', then re-run.)"
fi

if [ "$METHOD" = "profile" ]; then
  # Exports the profile's (ideally short-lived SSO) credentials straight into
  # repo secrets without printing them.
  CREDS="$(aws configure export-credentials --profile "$PROFILE" --format env-no-export)" \
    || die "Could not read credentials for '$PROFILE'. Try: aws sso login --profile $PROFILE"
  while IFS='=' read -r k v; do
    case "$k" in AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN) put_secret "$k" "$v" ;; esac
  done <<< "$CREDS"
  unset CREDS
  echo "  Stored credentials from profile '$PROFILE'."
else
  echo "  From IAM > Users > <admin user> > Security credentials > Create access key,"
  echo "  or the IAM Identity Center portal > Access keys. Input is hidden."
  KEY_ID="$(secret_prompt "Access key ID (starts with AKIA or ASIA)")"
  SECRET_KEY="$(secret_prompt "Secret access key")"
  TOKEN=""
  case "$KEY_ID" in ASIA*) TOKEN="$(secret_prompt "Session token (temporary credentials)")" ;; esac
  [[ "$KEY_ID" =~ ^A[SK]IA[A-Z0-9]{12,}$ ]] || die "That doesn't look like an access key ID (expected AKIA... or ASIA...)."
  [ -n "$SECRET_KEY" ] || die "Secret access key is empty."
  put_secret AWS_ACCESS_KEY_ID "$KEY_ID"
  put_secret AWS_SECRET_ACCESS_KEY "$SECRET_KEY"
  [ -z "$TOKEN" ] || put_secret AWS_SESSION_TOKEN "$TOKEN"
  unset KEY_ID SECRET_KEY TOKEN
  echo "  Stored as temporary repo secrets."
fi

bold "4/4  Running the Setup workflow on GitHub"
set +e
"$RUN" setup.yml -f project="$PROJECT" -f display_name="$DISPLAY" -f bundle_id="$BUNDLE" -f region="$REGION" -f deploy_dev=true
STATUS=$?
set -e

echo "  Removing one-time AWS secrets..."
for s in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN; do gh secret delete "$s" --repo "$REPO" >/dev/null 2>&1 || true; done
[ "$STATUS" = 0 ] || die "Setup workflow failed (see the log above). Fix and re-run: make setup"

git pull -q --rebase origin "$(git rev-parse --abbrev-ref HEAD)"

bold "Done. The first dev deploy is running (~10 min):"
echo "  gh run watch \$(gh run list --workflow deploy.yml --limit 1 --json databaseId -q '.[0].databaseId')"
cat <<'EOF'

  Next:
    make dev           run backend (:8080) + web (:5173) locally
    claude             start Claude Code; try: /kickoff <your idea>
    git push           to main -> CI deploys dev
EOF
