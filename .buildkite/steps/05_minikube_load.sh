#!/usr/bin/env bash
set -euo pipefail

# Set default BUILD_DIR
BUILD_DIR="${BUILDKITE_BUILD_CHECKOUT_PATH}/.buildkite/build"

# Source the build environment if it exists
if [ -f "${BUILDKITE_ENV_FILE:-}" ]; then
  source "$BUILDKITE_ENV_FILE"
fi

# Verify required files exist
if [ ! -f "$BUILD_DIR/.bk-tag" ]; then
  echo "--- Error: Required build files are missing"
  echo "Looking for: $BUILD_DIR/.bk-tag"
  echo "Current directory: $(pwd)"
  exit 1
fi

TAG="$(sed -n 's/^tag=//p' "$BUILD_DIR/.bk-tag")"
[ -n "$TAG" ] || { echo "FATAL: .bk-tag missing"; exit 1; }

echo "--- Loading images with tag: $TAG"
minikube image load --overwrite=true "hackermonk/order:$TAG"
minikube image load --overwrite=true "hackermonk/payment:$TAG"
# Optional dev tags:
minikube image load --overwrite=true hackermonk/order:dev || true
minikube image load --overwrite=true hackermonk/payment:dev || true
