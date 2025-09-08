#!/usr/bin/env bash
set -euo pipefail
: "${TAG:?TAG not set; setup step must export it}"
mkdir -p artifacts
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD:/work" aquasec/trivy:0.49.1 \
  image --no-progress --format sarif -o /work/artifacts/trivy-order.sarif "hackermonk/order:${TAG}" || true
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD:/work" aquasec/trivy:0.49.1 \
  image --no-progress --format sarif -o /work/artifacts/trivy-payment.sarif "hackermonk/payment:${TAG}" || true
