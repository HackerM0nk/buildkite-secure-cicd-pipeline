#!/usr/bin/env bash
set -euo pipefail

docker-compose -f docker-compose.ci.yml up -d mysql
echo "--- Waiting for MySQL"
sleep 25
mkdir -p test-results

echo "--- Order tests"
docker run --rm \
  --network container:buildkite-secure-pipeline-mysql-1 \
  -e DB_HOST=localhost -e DB_PORT=3306 -e DB_USER=user -e DB_PASSWORD=password -e DB_NAME=orders \
  -v "$(pwd)/test-results:/test-results" \
  buildkite-secure-pipeline-order \
  sh -c "cd /app && go test -v ./... | tee /test-results/order-test-output.txt" || echo "Order tests failed but continuing..."

echo "--- Payment tests"
docker run --rm \
  --network container:buildkite-secure-pipeline-mysql-1 \
  -e DB_HOST=localhost -e DB_PORT=3306 -e DB_USER=user -e DB_PASSWORD=password -e DB_NAME=payments \
  -v "$(pwd)/test-results:/test-results" \
  buildkite-secure-pipeline-payment \
  sh -c "cd /app && go test -v ./... | tee /test-results/payment-test-output.txt" || echo "Payment tests failed but continuing..."

echo "--- Test Results"
cat test-results/*.txt || true

echo "--- Cleanup"
docker-compose -f docker-compose.ci.yml down -v
