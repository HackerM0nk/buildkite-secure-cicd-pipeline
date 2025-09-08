#!/usr/bin/env bash
set -euo pipefail

ARCH="$(sed -n 's/^arch=//p' "$PWD/.bk-arch")"
TAG="$(sed -n 's/^tag=//p' "$PWD/.bk-tag")"
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
