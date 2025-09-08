#!/usr/bin/env bash
set -euo pipefail

# Source the build environment
if [ -f "${BUILDKITE_ENV_FILE:-}" ]; then
  source "$BUILDKITE_ENV_FILE"
fi

# Verify required environment variables
if [ -z "${TAG:-}" ]; then
  echo "--- Error: TAG environment variable is not set"
  env | sort
  exit 1
fi

echo "--- Loading images with tag: $TAG"
[ -n "$TAG" ] || { echo "FATAL: .bk-tag missing"; exit 1; }

echo "--- Loading images with tag: $TAG"
minikube image load --overwrite=true "hackermonk/order:$TAG"
minikube image load --overwrite=true "hackermonk/payment:$TAG"
# Optional dev tags:
minikube image load --overwrite=true hackermonk/order:dev || true
minikube image load --overwrite=true hackermonk/payment:dev || true
