#!/usr/bin/env bash
set -euo pipefail

ARCH="arm64"
PLATFORM="linux/arm64"
if [ -n "${BUILDKITE_COMMIT:-}" ]; then
  TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TAG="$(git rev-parse --short HEAD)"
else
  TAG="local-$(date +%s)"
fi
TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"

cat > build.env <<EOF
ARCH=$ARCH
PLATFORM=$PLATFORM
TAG=$TAG
EOF

echo "Setup: ARCH=$ARCH PLATFORM=$PLATFORM TAG=$TAG"
docker --version
kubectl version --client=true --output=yaml | sed -n '1,8p' || true
minikube version || true
kubectl config current-context || true

buildkite-agent artifact upload build.env

# Choose a short, safe tag and export it for subsequent steps
TAG="$(printf %s "${BUILDKITE_COMMIT:-local-$(date +%s)}" | cut -c1-7)"
echo "TAG=$TAG" >> "$BUILDKITE_ENV_FILE"
echo "Using TAG=$TAG"
