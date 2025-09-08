#!/usr/bin/env bash
set -euo pipefail

# --- Decide architecture/platform (M-series Mac)
ARCH="arm64"
PLATFORM="linux/arm64"

# --- Compute a single canonical TAG once
if [ -n "${BUILDKITE_COMMIT:-}" ]; then
  TAG="$(printf %s "$BUILDKITE_COMMIT" | cut -c1-7)"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TAG="$(git rev-parse --short HEAD)"
else
  TAG="local-$(date +%s)"
fi
# sanitize
TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"

# --- Persist for later steps (three ways for robustness)

# 1) Buildkite meta-data (best cross-step control plane)
buildkite-agent meta-data set tag "$TAG"

# 2) Artifact fallback
cat > build.env <<EOF
export ARCH=$ARCH
export PLATFORM=$PLATFORM
export TAG=$TAG
EOF
buildkite-agent artifact upload build.env

# 3) Also append to the job env file so future steps in this job see it
{
  echo "ARCH=$ARCH"
  echo "PLATFORM=$PLATFORM"
  echo "TAG=$TAG"
} >> "$BUILDKITE_ENV_FILE"

# --- Minimal workspace setup
mkdir -p artifacts .tools/bin

# --- Quick diagnostics (non-fatal where sensible)
echo "Setup: ARCH=$ARCH PLATFORM=$PLATFORM TAG=$TAG"
docker --version
kubectl version --client=true --output=yaml | sed -n '1,8p' || true
minikube version || true
kubectl config current-context || true
