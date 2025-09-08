#!/usr/bin/env bash
set -euo pipefail
mkdir -p artifacts
docker run --rm -v "$PWD:/src" -w /src returntocorp/semgrep:latest \
  semgrep --config p/ci --error --json -o artifacts/semgrep.json
