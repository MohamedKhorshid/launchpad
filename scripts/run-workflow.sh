#!/usr/bin/env bash
# Trigger a GitHub Actions workflow and follow it to completion.
# This is how humans and Claude deploy: nothing touches AWS from this machine.
#
#   scripts/run-workflow.sh deploy.yml -f env=dev -f component=backend
#   scripts/run-workflow.sh plan.yml -f env=dev
#   NO_WATCH=1 scripts/run-workflow.sh deploy.yml -f env=dev   # fire and forget
#   REF=my-branch scripts/run-workflow.sh deploy.yml -f env=dev
#
# Exit code mirrors the run's conclusion. On failure, prints the failed steps' logs.
# The last line is always: RUN_RESULT <conclusion> <url>
set -euo pipefail

WF="${1:?usage: run-workflow.sh <workflow.yml> [-f key=value ...]}"; shift
REF="${REF:-$(git rev-parse --abbrev-ref HEAD)}"

command -v gh >/dev/null || { echo "Install the GitHub CLI: https://cli.github.com" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Run: gh auth login" >&2; exit 1; }

# The workflow runs the code on GitHub, not your working tree.
if [ "$REF" = "$(git rev-parse --abbrev-ref HEAD)" ]; then
  git fetch -q origin "$REF" 2>/dev/null || true
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "Warning: uncommitted changes are NOT included in this run." >&2
  fi
  if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$REF" 2>/dev/null || echo none)" ]; then
    echo "Warning: local $REF differs from origin/$REF; the run uses what is on GitHub. Push first." >&2
  fi
fi

START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
gh workflow run "$WF" --ref "$REF" "$@"

# Find the run we just started (newest dispatch of this workflow since START).
ID=""
for _ in $(seq 1 20); do
  ID="$(gh run list --workflow "$WF" --event workflow_dispatch --branch "$REF" --limit 5 \
        --json databaseId,createdAt \
        -q "[.[] | select(.createdAt >= \"$START\")] | sort_by(.createdAt) | last | .databaseId // empty")"
  [ -n "$ID" ] && break
  sleep 3
done
[ -n "$ID" ] || { echo "Triggered $WF but could not find the run; check: gh run list --workflow $WF" >&2; exit 1; }

URL="$(gh run view "$ID" --json url -q .url)"
echo "Run $ID: $URL"
if [ "${NO_WATCH:-}" = "1" ]; then echo "RUN_RESULT started $URL"; exit 0; fi

gh run watch "$ID" --interval 10 --exit-status >/dev/null 2>&1 || true
CONCLUSION="$(gh run view "$ID" --json conclusion -q .conclusion)"

# Surface the machine-readable result lines the workflows print.
gh run view "$ID" --log 2>/dev/null | grep -oE '(DEPLOY_RESULT|PLAN_RESULT) .*' | grep -v '[$]' | sort -u || true

if [ "$CONCLUSION" != "success" ]; then
  echo "---- failed steps ----"
  gh run view "$ID" --log-failed 2>/dev/null | tail -80 || true
fi
echo "RUN_RESULT $CONCLUSION $URL"
[ "$CONCLUSION" = "success" ]
