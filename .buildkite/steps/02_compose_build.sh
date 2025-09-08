#!/usr/bin/env bash
set -euo pipefail

# Load build environment from artifact
if [ -f build.env ]; then
  echo "--- Loading build environment"
  set -a
  source build.env
  set +a
fi

echo "--- Build Environment"
echo "Using TAG: ${TAG:-not set}"
echo "Using ARCH: ${ARCH:-not set}"

# Enable BuildKit
export DOCKER_BUILDKIT=1

# Build services using docker-compose
echo "--- Building services with docker-compose"
if ! docker-compose -f docker-compose.ci.yml build --parallel; then
  echo "--- docker-compose build failed, trying without --parallel"
  # Try without parallel if it fails (some versions don't support it)
  docker-compose -f docker-compose.ci.yml build
fi

# Show disk usage
echo "--- Docker disk usage"
docker system df -v || true

# List built images
echo "--- Built images"
docker images || true
