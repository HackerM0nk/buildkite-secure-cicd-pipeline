#!/usr/bin/env bash
set -eo pipefail  # note: no -u until TAG is set

# --- Derive TAG deterministically in THIS step
if [ -n "${BUILDKITE_COMMIT:-}" ]; then
  TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TAG="$(git rev-parse --short HEAD)"
else
  TAG="local-$(date +%s)"
fi
export TAG

ARCH="arm64"
PLATFORM="linux/arm64"
echo "Building images"
echo "TAG=$TAG  PLATFORM=$PLATFORM"

# build order
docker buildx create --use --name bkx || docker buildx use bkx
docker buildx build \
  --platform "$PLATFORM" \
  -t "hackermonk/order:$TAG" \
  -f order/Dockerfile order --load

# build payment
docker buildx build \
  --platform "$PLATFORM" \
  -t "hackermonk/payment:$TAG" \
  -f payment/Dockerfile payment --load
