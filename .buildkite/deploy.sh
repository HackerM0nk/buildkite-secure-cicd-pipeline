#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/deploy-local.sh [namespace] [manifest_dir]
NAMESPACE="${1:-default}"
MANIFEST_DIR="${2:-kubernetes}"

# 1) Resolve TAG from CI artifact (.bk-tag) or fallbacks
TAG=""
if [[ -f .bk-tag ]]; then
  TAG="$(sed -n 's/^tag=//p' .bk-tag)"
fi
if [[ -z "${TAG}" && -n "${BUILDKITE_COMMIT:-}" ]]; then
  TAG="${BUILDKITE_COMMIT:0:7}"
fi
TAG="${TAG:-local-$(date +%s)}"

# 2) Images (no registry prefix)
ORDER_IMAGE="hackermonk/order:${TAG}"
PAYMENT_IMAGE="hackermonk/payment:${TAG}"

echo ">>> Namespace: ${NAMESPACE}"
echo ">>> Using images:"
echo "    ${ORDER_IMAGE}"
echo "    ${PAYMENT_IMAGE}"

# 3) Load images into Minikube cache (no registry)
minikube image load --overwrite=true "${ORDER_IMAGE}"
minikube image load --overwrite=true "${PAYMENT_IMAGE}"

# Optionally also load :dev for manual tinkering
# minikube image load --overwrite=true hackermonk/order:dev
# minikube image load --overwrite=true hackermonk/payment:dev

# 4) Apply manifests with envsubst (templated image vars)
export ORDER_IMAGE PAYMENT_IMAGE
for m in mysql-deployment.yaml order-deployment.yaml payment-deployment.yaml services.yaml; do
  f="${MANIFEST_DIR}/${m}"
  [[ -f "$f" ]] || { echo "Missing manifest: $f"; exit 1; }
  envsubst < "$f" | kubectl -n "$NAMESPACE" apply -f -
done

# 5) Rollouts
kubectl -n "$NAMESPACE" rollout status deploy/order --timeout=90s || true
kubectl -n "$NAMESPACE" rollout status deploy/payment --timeout=90s || true

# 6) Quick view
kubectl -n "$NAMESPACE" get pods -o wide
