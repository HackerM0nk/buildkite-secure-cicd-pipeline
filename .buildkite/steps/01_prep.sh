#!/usr/bin/env bash
set -euo pipefail

echo "--- Versions"
docker --version
kubectl version --client=true --output=yaml | sed -n '1,8p' || true
minikube version || true
echo "--- Current kube-context"
kubectl config current-context || true

echo "--- Decide architecture"
# Hardcode for M3 (arm64); switch to detection later if you prefer
echo "arch=arm64" > .bk-arch
cat .bk-arch

echo "--- Decide tag"
TAG=""
if printenv BUILDKITE_COMMIT >/dev/null 2>&1 && [ -n "$(printenv BUILDKITE_COMMIT)" ]; then
  TAG="$(printenv BUILDKITE_COMMIT | cut -c1-7)"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TAG="$(git rev-parse --short HEAD)"
else
  TAG="local-$(date +%s)"
fi

# sanitize and validate
TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"
[ -n "$TAG" ] || { echo "FATAL: computed TAG is empty"; exit 1; }
echo "tag=$TAG" > .bk-tag
echo "Using TAG=$TAG"
