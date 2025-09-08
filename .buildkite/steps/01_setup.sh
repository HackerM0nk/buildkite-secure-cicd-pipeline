#!/usr/bin/env bash
set -euo pipefail

# Target single-arch for Apple Silicon
ARCH="arm64"
PLATFORM="linux/arm64"

# Derive a short, safe TAG
if [ -n "${BUILDKITE_COMMIT:-}" ]; then
  TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TAG="$(git rev-parse --short HEAD)"
else
  TAG="local-$(date +%s)"
fi
TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"
[ -n "$TAG" ] || { echo "FATAL: TAG empty"; exit 1; }

cat > build.env <<EOF
ARCH=$ARCH
PLATFORM=$PLATFORM
TAG=$TAG
EOF

echo "--- Setup"
echo "ARCH=$ARCH"
echo "PLATFORM=$PLATFORM"
echo "TAG=$TAG"

echo "--- Versions"
docker --version
kubectl version --client=true --output=yaml | sed -n '1,8p' || true
minikube version || true
kubectl config current-context || true

# Persist state for later steps
buildkite-agent artifact upload build.env
