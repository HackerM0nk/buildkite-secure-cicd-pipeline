#!/usr/bin/env bash
set -euo pipefail

# Source the build environment
if [ -f "$BUILDKITE_ENV_FILE" ]; then
  source "$BUILDKITE_ENV_FILE"
fi

# Default BUILD_DIR if not set
BUILD_DIR="${BUILD_DIR:-$BUILDKITE_BUILD_CHECKOUT_PATH/.buildkite/build}"

TAG="$(sed -n 's/^tag=//p' "$BUILD_DIR/.bk-tag")"
[ -n "$TAG" ] || { echo "FATAL: .bk-tag missing"; exit 1; }

echo "--- Loading images with tag: $TAG"
minikube image load --overwrite=true "hackermonk/order:$TAG"
minikube image load --overwrite=true "hackermonk/payment:$TAG"
# Optional dev tags:
minikube image load --overwrite=true hackermonk/order:dev || true
minikube image load --overwrite=true hackermonk/payment:dev || true
