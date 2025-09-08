#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
TAG="$(sed -n 's/^tag=//p' "$REPO_ROOT/.bk-tag")"
[ -n "$TAG" ] || { echo "FATAL: .bk-tag missing"; exit 1; }

echo "--- Loading images with tag: $TAG"
minikube image load --overwrite=true "hackermonk/order:$TAG"
minikube image load --overwrite=true "hackermonk/payment:$TAG"
# Optional dev tags:
minikube image load --overwrite=true hackermonk/order:dev || true
minikube image load --overwrite=true hackermonk/payment:dev || true
