#!/usr/bin/env bash
set -euo pipefail

# Config knobs (optional)
GITLEAKS_IMG="${GITLEAKS_IMG:-zricethezav/gitleaks:8.18.4}"
BASELINE_PATH="${BASELINE_PATH:-.security/gitleaks-baseline.json}"
STRICT="${STRICT:-1}"     # 1 = fail pipeline on leaks; 0 = let pipeline continue (script exits 0)

mkdir -p artifacts

run_gitleaks_local() {
  echo "--- Running gitleaks (local binary)"
  cmd=( gitleaks detect --source . --redact
        --report-format sarif --report-path artifacts/gitleaks.sarif )
  if [ -f "$BASELINE_PATH" ]; then
    cmd+=( --baseline-path "$BASELINE_PATH" )
  fi
  echo "+ ${cmd[*]}"
  set +e
  "${cmd[@]}"
  rc=$?
  set -e
  echo "$rc" > artifacts/exitcode
}

run_gitleaks_container_tar() {
  echo "--- Running gitleaks (container, no bind mounts)"
  # Stream repo in, generate report to /out, stream /out back to host:artifacts/
  set +e
  tar -czf - . | docker run --rm -i --env "BASELINE=$BASELINE_PATH" "$GITLEAKS_IMG" \
    sh -c '
      set -e
      mkdir -p /src /out
      tar -C /src -xzf -
      set +e
      CMD="gitleaks detect --source /src --redact --report-format sarif --report-path /out/gitleaks.sarif"
      if [ -n "${BASELINE:-}" ] && [ -f "/src/${BASELINE}" ]; then
        CMD="$CMD --baseline-path /src/${BASELINE}"
      fi
      echo "+ $CMD" >&2
      sh -c "$CMD"
      rc=$?
      set -e
      echo "$rc" > /out/exitcode
      # Always stream results back, even if rc=1
      tar -C /out -czf - .
      # exit 0 so the tar makes it back; host will read /out/exitcode and decide
      exit 0
    ' | tar -xzf - -C artifacts
  rc=$(cat artifacts/exitcode 2>/dev/null || echo 2)
  set -e
  echo "$rc" > artifacts/exitcode
}

# Prefer local binary if present; else use container with tar streaming
if command -v gitleaks >/dev/null 2>&1; then
  run_gitleaks_local
else
  run_gitleaks_container_tar
fi

echo "--- Gitleaks SARIF written to artifacts/gitleaks.sarif"
rc=$(cat artifacts/exitcode || echo 2)
rm -f artifacts/exitcode

if [ "$rc" -ne 0 ]; then
  echo "gitleaks found leaks (exit $rc)."
  if [ "$STRICT" = "1" ]; then
    exit 1
  else
    echo "STRICT=0 → not failing the step."
    exit 0
  fi
fi
