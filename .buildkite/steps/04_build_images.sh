#!/usr/bin/env bash
set -euo pipefail

# Source the build environment
if [ -f "${BUILDKITE_ENV_FILE:-}" ]; then
  source "$BUILDKITE_ENV_FILE"
fi

# Set default BUILD_DIR if not set
BUILD_DIR="${BUILD_DIR:-${BUILDKITE_BUILD_CHECKOUT_PATH}/.buildkite/build}"

# Verify required environment variables
if [ -z "${TAG:-}" ]; then
  echo "--- Error: TAG environment variable is not set"
  echo "Available environment variables:"
  env | sort
  exit 1
fi

# Set architecture
ARCH="arm64"  # Hardcoded for M3
PLATFORM="linux/arm64"
GOARCH="arm64"

echo "--- Build Environment"
echo "Current directory: $(pwd)"
echo "Build directory: $BUILD_DIR"
echo "Using TAG: $TAG"
echo "Using ARCH: $ARCH ($PLATFORM)"
[ -n "$ARCH" ] || { echo "FATAL: .bk-arch missing"; exit 1; }
[ -n "$TAG" ]  || { echo "FATAL: .bk-tag missing"; exit 1; }

case "$ARCH" in
  arm64)        PLATFORM="linux/arm64"; GOARCH="arm64" ;;
  amd64|x86_64) PLATFORM="linux/amd64"; GOARCH="amd64" ;;
  *) echo "Unknown arch '$ARCH'"; exit 1 ;;
esac

echo "--- Using PLATFORM=$PLATFORM GOARCH=$GOARCH TAG=$TAG"
docker buildx create --use --name bkx || docker buildx use bkx

echo "--- Build Order"
docker buildx build \
  --platform "$PLATFORM" \
  --build-arg GOARCH="$GOARCH" \
  -t "hackermonk/order:$TAG" \
  -t "hackermonk/order:dev" \
  -f order/Dockerfile order \
  --load

echo "--- Build Payment"
docker buildx build \
  --platform "$PLATFORM" \
  --build-arg GOARCH="$GOARCH" \
  -t "hackermonk/payment:$TAG" \
  -t "hackermonk/payment:dev" \
  -f payment/Dockerfile payment \
  --load

echo "--- Local images"
docker images | grep -E 'hackermonk/(order|payment)' || true
