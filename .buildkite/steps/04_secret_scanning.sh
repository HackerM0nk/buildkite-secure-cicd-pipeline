#!/usr/bin/env bash
set -euo pipefail
mkdir -p artifacts
docker run --rm -v "$PWD:/work" zricethezav/gitleaks:latest \
  detect --source /work --redact \
  --report-format sarif --report-path /work/artifacts/gitleaks.sarif \
  --exit-code 1
