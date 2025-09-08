#!/usr/bin/env bash
set -euo pipefail

# Set default BUILD_DIR
BUILD_DIR="${BUILDKITE_BUILD_CHECKOUT_PATH}/.buildkite/build"

# Ensure build directory exists
mkdir -p "$BUILD_DIR"

# Source the build environment if it exists
if [ -f "${BUILDKITE_ENV_FILE:-}" ]; then
  source "$BUILDKITE_ENV_FILE"
fi

# Verify required files exist
if [ ! -f "$BUILD_DIR/.bk-arch" ] || [ ! -f "$BUILD_DIR/.bk-tag" ]; then
  echo "--- Error: Required build files are missing"
  echo "Looking for:"
  echo "  $BUILD_DIR/.bk-arch"
  echo "  $BUILD_DIR/.bk-tag"
  echo "Current directory: $(pwd)"
  echo "Directory contents:"
  ls -la "$BUILDKITE_BUILD_CHECKOUT_PATH/.buildkite" || true
  exit 1
fi

ARCH="$(sed -n 's/^arch=//p' "$BUILD_DIR/.bk-arch")"
TAG="$(sed -n 's/^tag=//p' "$BUILD_DIR/.bk-tag")"
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
