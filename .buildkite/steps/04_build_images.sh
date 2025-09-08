#!/usr/bin/env bash
set -euo pipefail

# Load build environment from artifact
if [ -f build.env ]; then
  echo "--- Loading build environment"
  set -a
  source build.env
  set +a
fi

# Verify required variables are set
if [ -z "${TAG:-}" ]; then
  echo "--- Error: TAG environment variable is not set"
  echo "Current environment variables:"
  env | sort
  exit 1
fi

# Set architecture (hardcoded for M3 Mac)
ARCH="arm64"
PLATFORM="linux/arm64"
GOARCH="arm64"

# Set image names
ORDER_IMAGE="hackermonk/order:$TAG"
PAYMENT_IMAGE="hackermonk/payment:$TAG"

echo "--- Build Environment"
echo "Current directory: $(pwd)"
echo "Using TAG: $TAG"
echo "Using ARCH: $ARCH ($PLATFORM)"

# Build order service
echo "--- Building order service"
cd order
DOCKER_BUILDKIT=1 docker build \
  --platform $PLATFORM \
  -t "$ORDER_IMAGE" \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --build-arg GOARCH=$GOARCH \
  .

# Build payment service
echo "--- Building payment service"
cd ../payment
DOCKER_BUILDKIT=1 docker build \
  --platform $PLATFORM \
  -t "$PAYMENT_IMAGE" \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --build-arg GOARCH=$GOARCH \
  .

# List built images
echo "--- Built images"
docker images | grep -E 'hackermonk/(order|payment)' || true

echo "--- Local images"
docker images | grep -E 'hackermonk/(order|payment)' || true
