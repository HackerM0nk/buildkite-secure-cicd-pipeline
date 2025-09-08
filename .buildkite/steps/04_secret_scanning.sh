#!/usr/bin/env bash
set -euo pipefail
export PATH="$PWD/.tools/bin:$HOME/.local/bin:$PATH"
mkdir -p artifacts

if [ "${USE_GITLEAKS_CONTAINER:-0}" = "1" ] || ! command -v gitleaks >/dev/null 2>&1; then
  echo "--- gitleaks via container (no host mount)"
  tar -czf - . | docker run --rm -i zricethezav/gitleaks:8.18.4 \
    sh -lc 'mkdir -p /src && tar -C /src -xzf - && \
            gitleaks detect --source /src --redact \
              --report-format sarif --report-path /src/artifacts/gitleaks.sarif --exit-code 1'
else
  gitleaks detect --source . --redact \
    --report-format sarif --report-path artifacts/gitleaks.sarif --exit-code 1
fi
