#!/usr/bin/env bash
set -euo pipefail

echo "--- Enable BuildKit"
export DOCKER_BUILDKIT=1
docker-compose -f docker-compose.ci.yml build --parallel
docker system df -v || true
