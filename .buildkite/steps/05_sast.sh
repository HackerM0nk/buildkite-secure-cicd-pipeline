#!/usr/bin/env bash
set -euo pipefail
export PATH="$PWD/.tools/bin:$HOME/.local/bin:$PATH"
mkdir -p artifacts

if [ "${USE_SEMGREP_CONTAINER:-0}" = "1" ] || ! command -v semgrep >/dev/null 2>&1; then
  echo "--- semgrep via container (no host mount)"
  tar -czf - . | docker run --rm -i returntocorp/semgrep:1.77.0 \
    sh -lc 'mkdir -p /src && tar -C /src -xzf - && \
            semgrep --config p/ci --error --json -o /src/artifacts/semgrep.json /src'
else
  semgrep --config p/ci --error --json -o artifacts/semgrep.json .
fi
