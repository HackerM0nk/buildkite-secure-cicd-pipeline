#!/usr/bin/env bash
set -euo pipefail

# Pull state from setup (ok if missing)
buildkite-agent artifact download build.env . >/dev/null 2>&1 || true
if [ -f build.env ]; then set -a; . build.env; set +a; fi

# Fallbacks for robustness
if [ -z "${TAG:-}" ]; then
  if [ -n "${BUILDKITE_COMMIT:-}" ]; then TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"; else TAG="local-$(date +%s)"; fi
  TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"
fi
: "${ARCH:=arm64}"
: "${PLATFORM:=linux/${ARCH}}"

ORDER_IMAGE="hackermonk/order:$TAG"
PAYMENT_IMAGE="hackermonk/payment:$TAG"

echo "--- Building images"
echo "ORDER_IMAGE:   $ORDER_IMAGE"
echo "PAYMENT_IMAGE: $PAYMENT_IMAGE"
echo "PLATFORM:      $PLATFORM"

export DOCKER_BUILDKIT=1

docker build --platform "$PLATFORM" -t "$ORDER_IMAGE"   -f order/Dockerfile   order
docker build --platform "$PLATFORM" -t "$PAYMENT_IMAGE" -f payment/Dockerfile payment

echo "--- Local images"
docker images | grep -E 'hackermonk/(order|payment)' || true

# (Optional) upload build.env again if you mutate it (we don't)
