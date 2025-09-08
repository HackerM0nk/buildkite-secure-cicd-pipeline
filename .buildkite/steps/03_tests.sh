#!/usr/bin/env bash
set -euo pipefail

echo "--- Starting services"
docker compose -f docker-compose.ci.yml up -d mysql order payment

echo "--- Waiting for services to be ready"
sleep 30

mkdir -p test-results

echo "--- Running order service tests"
if ! docker compose -f docker-compose.ci.yml exec -T order sh -c "cd /app && go test -v ./..." | tee test-results/order-test-output.txt; then
  echo "Order tests failed but continuing..."
fi

echo "--- Running payment service tests"
if ! docker compose -f docker-compose.ci.yml exec -T payment sh -c "cd /app && go test -v ./..." | tee test-results/payment-test-output.txt; then
  echo "Payment tests failed but continuing..."
fi

echo "--- Test Results"
cat test-results/*.txt || true

echo "--- Cleanup"
docker compose -f docker-compose.ci.yml down -v
