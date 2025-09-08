#!/usr/bin/env bash
set -euo pipefail

# Decide ARCH (M3 Mac)
ARCH="arm64"            # change to detection later if you want
PLATFORM="linux/arm64"  # derived

# Decide TAG (prefer BK commit; fallback to git; else epoch)
if [ -n "${BUILDKITE_COMMIT:-}" ]; then
  TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TAG="$(git rev-parse --short HEAD)"
else
  TAG="local-$(date +%s)"
fi
TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"
[ -n "$TAG" ] || { echo "FATAL: TAG empty"; exit 1; }

# Persist for other steps
cat > build.env <<EOF
ARCH=$ARCH
PLATFORM=$PLATFORM
TAG=$TAG
EOF

# Also export into the current job environment (Buildkite-supported)
if [ -n "${BUILDKITE_ENV_FILE:-}" ]; then
  {
    echo "ARCH=$ARCH"
    echo "PLATFORM=$PLATFORM"
    echo "TAG=$TAG"
  } >> "$BUILDKITE_ENV_FILE"
fi

echo "--- Setup:"
echo "  ARCH=$ARCH"
echo "  PLATFORM=$PLATFORM"
echo "  TAG=$TAG"

echo "--- Versions"
docker --version
kubectl version --client=true --output=yaml | sed -n '1,8p' || true
minikube version || true
kubectl config current-context || true
