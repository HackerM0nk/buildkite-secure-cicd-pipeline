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

echo "--- Deploying with tag: $TAG"
[ -n "$TAG" ] || { echo "FATAL: .bk-tag missing"; exit 1; }

export ORDER_IMAGE="hackermonk/order:$TAG"
export PAYMENT_IMAGE="hackermonk/payment:$TAG"
echo "--- Using images:"
echo "  $ORDER_IMAGE"
echo "  $PAYMENT_IMAGE"

if ! command -v envsubst >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y gettext-base
  elif command -v brew >/dev/null 2>&1; then
    brew install gettext || true
    brew link --force gettext || true
  else
    echo "envsubst not available and no package manager found"; exit 1
  fi
fi

cd kubernetes
for m in mysql-deployment.yaml order-deployment.yaml payment-deployment.yaml services.yaml; do
  [ -f "$m" ] || { echo "Missing $m"; exit 1; }
  echo "--- Applying $m"
  envsubst < "$m" | kubectl apply -f -
done

echo "--- Rollout status"
kubectl rollout status deploy/order --timeout=90s || true
kubectl rollout status deploy/payment --timeout=90s || true
echo "--- Pods"
kubectl get pods -o wide
