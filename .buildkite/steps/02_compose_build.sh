#!/usr/bin/env bash
set -euxo pipefail

echo "--- Build Environment"
echo "Build number: $BUILDKITE_BUILD_NUMBER"
echo "Commit: $BUILDKITE_COMMIT"
echo "Tag: $TAG"
echo "Architecture: $ARCH"

# Enable BuildKit
export DOCKER_BUILDKIT=1

# Build services using docker-compose
echo "--- Building services with docker-compose"
docker-compose -f docker-compose.ci.yml build --build-arg TAG=$TAG

# Show disk usage
echo "--- Docker disk usage"
docker system df -v || true

# List built images
echo "--- Built images"
docker images | grep -E 'order|payment' || true
