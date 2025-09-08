#!/usr/bin/env bash
set -euo pipefail

[ -f build.env ] && set -a && . build.env && set +a
[ -n "${TAG:-}" ] || { echo "Missing TAG"; exit 1; }

ORDER_IMAGE="hackermonk/order:$TAG"
PAYMENT_IMAGE="hackermonk/payment:$TAG"

echo "--- minikube image load"
minikube image load --overwrite=true "$ORDER_IMAGE"
minikube image load --overwrite=true "$PAYMENT_IMAGE"

echo "--- Deploy manifests (envsubst)"
export ORDER_IMAGE PAYMENT_IMAGE

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
kubectl get pods -o wide
