#!/usr/bin/env bash
set -euo pipefail

# Usage: .buildkite/deploy.sh [manifest_dir]
# We DO NOT pass a namespace here; manifests already specify their own namespaces.
MANIFEST_DIR="${1:-kubernetes}"

# --- Resolve TAG from artifact or fallbacks (robust) ---
TAG=""
if [[ -f build.env ]]; then
  # Preferred: state from earlier step
  set -a; source build.env; set +a
  TAG="${TAG:-}"
fi
if [[ -z "${TAG}" && -f .bk-tag ]]; then
  TAG="$(sed -n 's/^tag=//p' .bk-tag)"
fi
if [[ -z "${TAG}" && -n "${BUILDKITE_COMMIT:-}" ]]; then
  TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"
fi
TAG="${TAG:-local-$(date +%s)}"
TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"

ORDER_IMAGE="hackermonk/order:${TAG}"
PAYMENT_IMAGE="hackermonk/payment:${TAG}"
export ORDER_IMAGE PAYMENT_IMAGE

echo ">>> Using images:"
echo "    ${ORDER_IMAGE}"
echo "    ${PAYMENT_IMAGE}"

# --- Ensure envsubst or provide a fallback ---
apply_tmpl () {
  local file="$1"
  if command -v envsubst >/dev/null 2>&1; then
    envsubst < "$file" | kubectl apply -f -
  else
    # Fallback: replace only the two vars we care about
    perl -pe 's/\$\{ORDER_IMAGE\}/$ENV{ORDER_IMAGE}/g; s/\$\{PAYMENT_IMAGE\}/$ENV{PAYMENT_IMAGE}/g' "$file" \
    | kubectl apply -f -
  fi
}

# --- Load images into Minikube (no registry) ---
minikube image load --overwrite=true "${ORDER_IMAGE}"
minikube image load --overwrite=true "${PAYMENT_IMAGE}"

# --- Apply manifests in a safe order ---
# 1) Namespaces first (no -n; let YAML namespaces stand)
if [[ -f "${MANIFEST_DIR}/namespaces.yaml" ]]; then
  kubectl apply -f "${MANIFEST_DIR}/namespaces.yaml"
fi

# 2) MySQL (creates mysql ns deploy + pvc)
[[ -f "${MANIFEST_DIR}/mysql-deployment.yaml" ]] \
  && apply_tmpl "${MANIFEST_DIR}/mysql-deployment.yaml"

# 3) Services (contains mysql/order/payment services; each has its own namespace)
[[ -f "${MANIFEST_DIR}/services.yaml" ]] \
  && kubectl apply -f "${MANIFEST_DIR}/services.yaml"

# 4) App deployments (templated images)
[[ -f "${MANIFEST_DIR}/order-deployment.yaml" ]] \
  && apply_tmpl "${MANIFEST_DIR}/order-deployment.yaml"
[[ -f "${MANIFEST_DIR}/payment-deployment.yaml" ]] \
  && apply_tmpl "${MANIFEST_DIR}/payment-deployment.yaml"

# --- Rollouts per namespace (don’t force a single -n) ---
kubectl -n mysql   rollout status deploy/mysql   --timeout=120s || true
kubectl -n order   rollout status deploy/order   --timeout=120s || true
kubectl -n payment rollout status deploy/payment --timeout=120s || true

# --- Quick status ---
echo ">>> Pods:"
kubectl -n mysql   get pods -o wide || true
kubectl -n order   get pods -o wide || true
kubectl -n payment get pods -o wide || true
