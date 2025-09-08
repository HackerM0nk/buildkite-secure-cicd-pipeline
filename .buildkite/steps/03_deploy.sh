#!/usr/bin/env bash
set -euo pipefail

buildkite-agent artifact download build.env . >/dev/null 2>&1 || true
if [ -f build.env ]; then set -a; . build.env; set +a; fi
if [ -z "${TAG:-}" ]; then
  if [ -n "${BUILDKITE_COMMIT:-}" ]; then TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"; else TAG="local-$(date +%s)"; fi
  TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"
fi

ORDER_IMAGE="hackermonk/order:$TAG"
PAYMENT_IMAGE="hackermonk/payment:$TAG"
export ORDER_IMAGE PAYMENT_IMAGE

echo "--- Minikube image load"
minikube image load --overwrite=true "$ORDER_IMAGE"
minikube image load --overwrite=true "$PAYMENT_IMAGE"

apply_tmpl () {
  local f="$1"
  if command -v envsubst >/dev/null 2>&1; then
    envsubst < "$f" | kubectl apply -f -
  else
    perl -pe 's/\$\{ORDER_IMAGE\}/$ENV{ORDER_IMAGE}/g; s/\$\{PAYMENT_IMAGE\}/$ENV{PAYMENT_IMAGE}/g' "$f" | kubectl apply -f -
  fi
}

echo "--- Applying namespaces first"
kubectl apply -f kubernetes/namespaces.yaml

echo "--- Applying deployments/services"
apply_tmpl kubernetes/mysql-deployment.yaml
apply_tmpl kubernetes/order-deployment.yaml
apply_tmpl kubernetes/payment-deployment.yaml
kubectl apply -f kubernetes/services.yaml

echo "--- Rollout status"
kubectl rollout status deploy/order --timeout=90s || true
kubectl rollout status deploy/payment --timeout=90s || true
kubectl get pods -o wide
