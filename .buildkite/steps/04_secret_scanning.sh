#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p artifacts

STRICT="${GITLEAKS_STRICT:-0}"

run_gitleaks () {
  gitleaks detect --redact \
    --report-format sarif --report-path artifacts/gitleaks.sarif \
    --exit-code 1
}

if run_gitleaks; then
  echo "Gitleaks: no leaks found"
else
  echo "Gitleaks: leaks found (exit 1)"
  if [[ "$STRICT" = "1" ]]; then
    exit 1
  else
    echo "Soft-failing (GITLEAKS_STRICT!=1). See artifacts/gitleaks.sarif"
  fi
fi

buildkite-agent artifact upload artifacts/gitleaks.sarif || true
