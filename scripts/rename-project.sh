#!/usr/bin/env bash
# Replace template placeholders with the real project identity.
# Run by .github/workflows/setup.yml; safe to run locally too.
#   scripts/rename-project.sh <slug> "<Display Name>" <bundle.id>
set -euo pipefail

SLUG="${1:?slug}"; NAME="${2:?display name}"; BUNDLE="${3:?bundle id}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

[[ "$SLUG" =~ ^[a-z][a-z0-9-]{2,24}$ ]] || { echo "Invalid slug '$SLUG' (3-25 chars: a-z, 0-9, -)" >&2; exit 1; }
[[ "$BUNDLE" =~ ^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9]*)+$ ]] || { echo "Invalid bundle id '$BUNDLE'" >&2; exit 1; }

export SLUG NAME BUNDLE
# .github is excluded: the workflow token may not edit workflow files.
grep -rIl --exclude-dir={node_modules,.git,.github,dist,bin,.terraform,.expo} \
  -e 'launchpad' -e 'Launchpad' . | grep -v 'scripts/rename-project.sh' | while read -r f; do
  perl -pi -e 's/com\.example\.launchpad/$ENV{BUNDLE}/g; s/Launchpad/$ENV{NAME}/g; s/(?<!MohamedKhorshid\/)launchpad/$ENV{SLUG}/g' "$f"
done

if command -v gofmt >/dev/null; then (cd backend && gofmt -w .); fi
echo "Renamed to $NAME ($SLUG, $BUNDLE)"
