#!/usr/bin/env bash
# CI-only helper: run one shell command on an EC2 instance through SSM and wait.
#   devops/scripts/ssm-run.sh <instance-id> "<command>" "<comment>"
# Prints the command output; exits non-zero if it fails or times out.
# Waits up to 5 minutes: on a first deploy the instance may still be booting.
set -euo pipefail

INSTANCE="${1:?instance id}"; CMD="${2:?command}"; COMMENT="${3:-ssm-run}"

CMD_ID="$(aws ssm send-command \
  --instance-ids "$INSTANCE" \
  --document-name AWS-RunShellScript \
  --comment "$COMMENT" \
  --parameters "commands=[\"$CMD\"]" \
  --query Command.CommandId --output text)"

for _ in $(seq 1 60); do
  STATUS="$(aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$INSTANCE" \
    --query Status --output text 2>/dev/null || echo Pending)"
  case "$STATUS" in
    Success|Failed|Cancelled|TimedOut) break ;;
  esac
  sleep 5
done

aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$INSTANCE" \
  --query '[StandardOutputContent,StandardErrorContent]' --output text 2>/dev/null || true
case "${STATUS:-}" in
  Success) exit 0 ;;
  Failed|Cancelled|TimedOut) echo "SSM command failed ($STATUS) on $INSTANCE" >&2; exit 1 ;;
  *) echo "Timed out waiting for SSM on $INSTANCE (still booting, or the SSM agent can't reach AWS)" >&2; exit 1 ;;
esac
