#!/bin/bash
set -euo pipefail

if [ -z "${REPOS:-}" ]; then
  echo "REPOS environment variable must be set" >&2
  exit 1
fi

exec python3 /scripts/org_coding_hours.py "$@"
