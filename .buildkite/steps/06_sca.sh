#!/usr/bin/env bash
set -euo pipefail
mkdir -p artifacts
docker run --rm -v "$PWD:/work" -w /work golang:1.22 bash -lc '
  set -e
  go env -w GOPROXY=https://proxy.golang.org,direct
  go install golang.org/x/vuln/cmd/govulncheck@latest
  (cd order && go mod download && govulncheck ./... || true)
  (cd payment && go mod download && govulncheck ./... || true)
' | tee artifacts/govulncheck.txt

docker run --rm -v "$PWD:/work" aquasec/trivy:0.49.1 \
  fs --no-progress --format sarif -o /work/artifacts/trivy-fs.sarif \
  --security-checks vuln,config /work || true
