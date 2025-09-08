#!/usr/bin/env bash
set -euo pipefail

# Load env
[ -f build.env ] && set -a && . build.env && set +a
[ -n "${TAG:-}" ] && [ -n "${PLATFORM:-}" ] || { echo "Missing TAG/PLATFORM"; exit 1; }

ORDER_IMAGE="hackermonk/order:$TAG"
PAYMENT_IMAGE="hackermonk/payment:$TAG"

echo "--- Build images"
echo "  ORDER_IMAGE:   $ORDER_IMAGE"
echo "  PAYMENT_IMAGE: $PAYMENT_IMAGE"
echo "  PLATFORM:      $PLATFORM"

export DOCKER_BUILDKIT=1

# Order
docker build \
  --platform "$PLATFORM" \
  --build-arg GOARCH="${ARCH:-arm64}" \
  -t "$ORDER_IMAGE" \
  -f order/Dockerfile order

# Payment
docker build \
  --platform "$PLATFORM" \
  --build-arg GOARCH="${ARCH:-arm64}" \
  -t "$PAYMENT_IMAGE" \
  -f payment/Dockerfile payment

echo "--- Local images"
docker images | grep -E 'hackermonk/(order|payment)' || true
