#!/usr/bin/env bash
set -euo pipefail

# Create build directory in the workspace
BUILD_DIR="${BUILDKITE_BUILD_CHECKOUT_PATH}/.buildkite/build"

# Ensure build directory exists and is writable
mkdir -p "$BUILD_DIR"
chmod 777 "$BUILD_DIR"

# Print debug info
echo "--- Build Environment"
echo "Current directory: $(pwd)"
echo "Build directory: $BUILD_DIR"
echo "User: $(whoami)"
echo "Directory permissions:"
ls -ld "$BUILD_DIR" || true

# Create build files
echo "--- Creating build files"
echo "arch=arm64" > "$BUILD_DIR/.bk-arch"
echo "Created $BUILD_DIR/.bk-arch"
cat "$BUILD_DIR/.bk-arch"

# Set tag
TAG="${BUILDKITE_COMMIT:0:7}"
[ -n "$TAG" ] || TAG="local-$(date +%s)"
TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"

echo "tag=$TAG" > "$BUILD_DIR/.bk-tag"
echo "Created $BUILD_DIR/.bk-tag"
cat "$BUILD_DIR/.bk-tag"

# Verify files were created
if [ ! -f "$BUILD_DIR/.bk-arch" ] || [ ! -f "$BUILD_DIR/.bk-tag" ]; then
  echo "--- Error: Failed to create build files"
  echo "Current directory: $(pwd)"
  echo "Build directory contents:"
  ls -la "$BUILD_DIR" || true
  exit 1
fi

echo "--- Versions"
docker --version
kubectl version --client=true --output=yaml | sed -n '1,8p' || true
minikube version || true
echo "--- Current kube-context"
kubectl config current-context || true

# Export BUILD_DIR for other steps
echo "--- Exporting build environment"
echo "BUILD_DIR=$BUILD_DIR" > "$BUILDKITE_ENV_FILE"
echo "TAG=$TAG" >> "$BUILDKITE_ENV_FILE"
chmod 644 "$BUILDKITE_ENV_FILE"

# Verify environment file
echo "--- Environment file contents"
cat "$BUILDKITE_ENV_FILE" || true
