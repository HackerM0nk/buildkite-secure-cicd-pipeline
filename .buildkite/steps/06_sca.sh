#!/usr/bin/env bash
set -euo pipefail
export PATH="$PWD/.tools/bin:$HOME/.local/bin:$PATH"
mkdir -p artifacts

if [ "${USE_TRIVY_CONTAINER:-0}" = "1" ] || ! command -v trivy >/dev/null 2>&1; then
  echo "--- trivy fs via container (no host mount)"
  tar -czf - . | docker run --rm -i aquasec/trivy:0.49.1 \
    sh -lc 'mkdir -p /src && tar -C /src -xzf - && \
            trivy fs --no-progress --format sarif -o /src/artifacts/trivy-fs.sarif \
              --security-checks vuln,config /src'
else
  trivy fs --no-progress --format sarif -o artifacts/trivy-fs.sarif \
    --security-checks vuln,config .
fi
