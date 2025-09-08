#!/usr/bin/env bash
set -euo pipefail

[ -f build.env ] && set -a && . build.env && set +a
[ -n "${TAG:-}" ] || { echo "Missing TAG"; exit 1; }

ORDER_IMAGE="hackermonk/order:$TAG"
PAYMENT_IMAGE="hackermonk/payment:$TAG"
mkdir -p security-reports

echo "=== Secrets scan (gitleaks) - non-blocking first ==="
docker run --rm -v "$(pwd):/repo" zricethezav/gitleaks:latest \
  detect -s /repo -v --no-banner --report-format json --report-path /repo/security-reports/gitleaks.json \
  || echo "[WARN] gitleaks found issues (not failing yet)"

echo "=== SAST (gosec) on order ==="
docker run --rm -v "$(pwd)/order:/src" -w /src securego/gosec \
  -fmt=json -out=/src/../security-reports/gosec-order.json ./... \
  || echo "[WARN] gosec(order) issues (not failing yet)"

echo "=== SAST (gosec) on payment ==="
docker run --rm -v "$(pwd)/payment:/src" -w /src securego/gosec \
  -fmt=json -out=/src/../security-reports/gosec-payment.json ./... \
  || echo "[WARN] gosec(payment) issues (not failing yet)"

echo "=== SCA (Trivy) – filesystem ==="
docker run --rm -v "$(pwd):/repo" -w /repo aquasec/trivy:latest fs \
  --scanners vuln,misconfig,secret --skip-dirs .git --no-progress --format json \
  --output /repo/security-reports/trivy-fs.json /repo \
  || echo "[WARN] trivy fs found issues (not failing yet)"

echo "=== SCA (Trivy) – images ==="
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$HOME/.cache:/root/.cache" aquasec/trivy:latest image \
  --no-progress --format json -o /tmp/trivy-order.json "$ORDER_IMAGE" \
  || echo "[WARN] trivy image (order) issues (not failing yet)"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$HOME/.cache:/root/.cache" aquasec/trivy:latest image \
  --no-progress --format json -o /tmp/trivy-payment.json "$PAYMENT_IMAGE" \
  || echo "[WARN] trivy image (payment) issues (not failing yet)"
# copy out
CID=$(docker create busybox); docker cp "$CID:/tmp/trivy-order.json" security-reports/ || true; docker rm -v "$CID" >/dev/null 2>&1 || true
CID=$(docker create busybox); docker cp "$CID:/tmp/trivy-payment.json" security-reports/ || true; docker rm -v "$CID" >/dev/null 2>&1 || true

echo "=== (Optional later) govulncheck ==="
# Example (needs go toolchain; can run in golang container if desired)

echo "--- Security reports in ./security-reports"
ls -l security-reports || true

# After you tune noise, you can enforce policy, e.g.:
# export SCAN_STRICT=true
# if [ "${SCAN_STRICT:-}" = "true" ]; then
#   # parse JSON, fail on HIGH/CRITICAL, etc.
# fi
