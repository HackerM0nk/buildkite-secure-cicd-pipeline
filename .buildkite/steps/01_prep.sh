#!/usr/bin/env bash
set -euo pipefail

# Create build directory in the workspace
BUILD_DIR="${BUILDKITE_BUILD_CHECKOUT_PATH}/.buildkite/build"
mkdir -p "$BUILD_DIR"

# Ensure we can write to the build directory
if ! touch "$BUILD_DIR/.test-write" 2>/dev/null; then
  echo "--- Error: Cannot write to build directory: $BUILD_DIR"
  echo "Current user: $(whoami)"
  echo "Directory permissions:"
  ls -ld "$BUILD_DIR" || true
  exit 1
fi
rm -f "$BUILD_DIR/.test-write"

echo "--- Versions"
docker --version
kubectl version --client=true --output=yaml | sed -n '1,8p' || true
minikube version || true
echo "--- Current kube-context"
kubectl config current-context || true

echo "--- Decide architecture"
# Hardcode for M3 (arm64); switch to detection later if you prefer
echo "arch=arm64" > "$BUILD_DIR/.bk-arch"
cat "$BUILD_DIR/.bk-arch"

echo "--- Decide tag"
TAG=""
if printenv BUILDKITE_COMMIT >/dev/null 2>&1 && [ -n "$(printenv BUILDKITE_COMMIT)" ]; then
  TAG="$(printenv BUILDKITE_COMMIT | cut -c1-7)"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TAG="$(git rev-parse --short HEAD)"
else
  TAG="local-$(date +%s)"
fi

# sanitize and validate
TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"
[ -n "$TAG" ] || { echo "FATAL: computed TAG is empty"; exit 1; }
echo "tag=$TAG" > "$BUILD_DIR/.bk-tag"
echo "Using TAG=$TAG"

# Create build files
echo "--- Creating build files"
echo "arch=arm64" > "$BUILD_DIR/.bk-arch"
cat "$BUILD_DIR/.bk-arch"

# Set tag
TAG="${BUILDKITE_COMMIT:0:7:-$BUILDKITE_BUILD_NUMBER}"
[ -n "$TAG" ] || TAG="local-$(date +%s)"
TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"
echo "tag=$TAG" > "$BUILD_DIR/.bk-tag"

# Export BUILD_DIR for other steps
echo "--- Exporting build environment"
echo "BUILD_DIR=$BUILD_DIR" > "$BUILDKITE_ENV_FILE"
chmod 644 "$BUILDKITE_ENV_FILE"
