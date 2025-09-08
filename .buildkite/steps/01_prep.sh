#!/usr/bin/env bash
set -euo pipefail

# Set default values
export ARCH=arm64
export TAG=${BUILDKITE_COMMIT:0:7}
[ -n "$TAG" ] || TAG="local-$(date +%s)"
TAG="$(printf %s "$TAG" | tr -c 'A-Za-z0-9_.-' '-')"

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

# Set build-specific environment variables
echo "--- Setting up build environment"
echo "Architecture: $ARCH"
echo "Build tag: $TAG"

echo "tag=$TAG" > "$BUILD_DIR/.bk-tag"
echo "Created $BUILD_DIR/.bk-tag"
cat "$BUILD_DIR/.bk-tag"

# Create build.env for artifact passing
echo "--- Creating build environment file"
{
  echo "export BUILD_DIR=$BUILD_DIR"
  echo "export TAG=$TAG"
  echo "export ARCH=$ARCH"
} > build.env

# Also export to Buildkite environment
{
  echo "BUILD_DIR=$BUILD_DIR"
  echo "TAG=$TAG"
  echo "ARCH=$ARCH"
} >> "$BUILDKITE_ENV_FILE"

# Make sure the env file is readable
chmod 644 build.env

# Verify files were created
if [ ! -f "$BUILD_DIR/.bk-arch" ] || [ ! -f "$BUILD_DIR/.bk-tag" ] || [ ! -f "build.env" ]; then
  echo "--- Error: Failed to create build files"
  echo "Current directory: $(pwd)"
  echo "Build directory contents:"
  ls -la "$BUILD_DIR" || true
  echo "Current directory contents:"
  ls -la . || true
  exit 1
fi

echo "--- Build environment setup complete"
echo "TAG set to: $TAG"
echo "BUILD_DIR set to: $BUILD_DIR"

echo "--- Versions"
docker --version
kubectl version --client=true --output=yaml | sed -n '1,8p' || true
minikube version || true
echo "--- Current kube-context"
kubectl config current-context || true

chmod 644 "$BUILDKITE_ENV_FILE"

# Verify environment file
echo "--- Environment file contents"
cat "$BUILDKITE_ENV_FILE" || true
