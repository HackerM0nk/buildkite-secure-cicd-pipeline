#!/usr/bin/env bash
set -eo pipefail  # avoid -u until TAG is initialized

# --- Derive TAG deterministically in THIS step too
if [ -n "${TAG:-}" ]; then
  :  # keep provided value
elif [ -n "${BUILDKITE_COMMIT:-}" ]; then
  TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TAG="$(git rev-parse --short HEAD)"
else
  TAG="local-$(date +%s)"
fi
export TAG

# images
export ORDER_IMAGE="hackermonk/order:$TAG"
export PAYMENT_IMAGE="hackermonk/payment:$TAG"
VARS='${ORDER_IMAGE} ${PAYMENT_IMAGE}'

echo "Minikube image load"
minikube image load --overwrite=true "$ORDER_IMAGE"
minikube image load --overwrite=true "$PAYMENT_IMAGE"

# namespaces first
kubectl apply -f kubernetes/namespaces.yaml

# mysql + services
envsubst "$VARS" < kubernetes/mysql-deployment.yaml | kubectl apply --dry-run=client -f -
envsubst "$VARS" < kubernetes/mysql-deployment.yaml | kubectl apply -f -
kubectl apply -f kubernetes/services.yaml

# deployments (order, payment)
for m in order-deployment.yaml payment-deployment.yaml; do
  echo "Applying $m with TAG=$TAG"
  envsubst "$VARS" < "kubernetes/$m" | kubectl apply --dry-run=client -f -
  envsubst "$VARS" < "kubernetes/$m" | kubectl apply -f -
done

# rollout status (non-fatal)
kubectl -n order   rollout status deploy/order   --timeout=120s || true
kubectl -n payment rollout status deploy/payment --timeout=120s || true
